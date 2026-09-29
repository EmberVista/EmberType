import Foundation
import NaturalLanguage

/// "Spoken punctuation only" mode for dictation.
///
/// Speech models (Parakeet, Whisper) punctuate on their own: they end every
/// utterance with a period, capitalize the first word, and write spoken
/// punctuation out as words ("hello comma how are you question mark.").
/// With this mode on, the model's own punctuation is removed, only the
/// punctuation the user says is inserted, and the first word is capitalized
/// only when the cursor sits at the start of a sentence. That makes
/// inserting a word into the middle of an existing sentence work.
struct SpokenPunctuationProcessor {
    static let settingKey = "IsSpokenPunctuationEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: settingKey)
    }

    // How a symbol joins its neighbours.
    private enum Attach {
        case left      // "word," — no space before
        case right     // "(word" — no space after
        case both      // "well-known" — no space either side
        case lineBreak // "\n" — no spaces either side
        case spaced    // "Edit > Start" — spaces both sides
    }

    private struct Command {
        let words: [String]
        let symbol: String
        let attach: Attach
        let endsSentence: Bool
    }

    private static let commands: [Command] = {
        var list: [Command] = []
        func add(_ phrases: [String], _ symbol: String, _ attach: Attach, endsSentence: Bool = false) {
            for phrase in phrases {
                list.append(Command(words: phrase.split(separator: " ").map(String.init),
                                    symbol: symbol, attach: attach, endsSentence: endsSentence))
            }
        }
        add(["period", "full stop"], ".", .left, endsSentence: true)
        add(["question mark"], "?", .left, endsSentence: true)
        add(["exclamation point", "exclamation mark"], "!", .left, endsSentence: true)
        add(["comma"], ",", .left)
        add(["colon"], ":", .left)
        add(["semicolon", "semi-colon", "semi colon"], ";", .left)
        add(["ellipsis"], "...", .left)
        // "paren" is often heard as "parent" or "parentheses".
        let parens = ["paren", "parent", "parenthesis", "parentheses"]
        add(parens.flatMap { ["open \($0)", "left \($0)"] }, "(", .right)
        add(parens.flatMap { ["close \($0)", "closed \($0)", "right \($0)"] }, ")", .left)
        add(["open quote", "begin quote", "start quote"], "\"", .right)
        add(["close quote", "closed quote", "end quote", "unquote"], "\"", .left)
        add(["open single quote"], "'", .right)
        add(["close single quote", "closed single quote"], "'", .left)
        add(["hyphen"], "-", .both)
        add(["em dash"], "—", .both)
        // "sign" keeps ordinary phrases like "greater than expected" as words.
        add(["greater than sign"], ">", .spaced)
        add(["less than sign"], "<", .spaced)
        add(["new line"], "\n", .lineBreak, endsSentence: true)
        add(["new paragraph"], "\n\n", .lineBreak, endsSentence: true)
        // Longest phrases first so "open paren" wins over shorter matches.
        return list.sorted { $0.words.count > $1.words.count }
    }()

    /// Saying "literal" before a command word types the word itself:
    /// "the trial literal period ends" → "the trial period ends".
    private static let literalPrefix = "literal"

    private static let leadingStrip = CharacterSet(charactersIn: "\"“”‘¿¡(")
    private static let trailingStrip = CharacterSet(charactersIn: ".,?!;:\"“”’)…")
    private static let sentenceEnders = CharacterSet(charactersIn: ".?!")

    private enum Piece {
        case word(String, wasSentenceStart: Bool)
        case symbol(String, Attach, endsSentence: Bool)
    }

    /// - Parameters:
    ///   - text: the transcript as the speech model produced it.
    ///   - capitalizeFirstWord: true when the cursor is at the start of the
    ///     document or after sentence-ending punctuation. Pass false when
    ///     inserting mid-sentence or when the context is unknown.
    static func process(_ text: String, capitalizeFirstWord: Bool) -> String {
        let properNouns = namedEntities(in: text)
        let rawTokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        // 1. Remove the model's own punctuation, remembering which words it
        //    treated as sentence starts (so its capital letter can be undone).
        var tokens: [(word: String, wasSentenceStart: Bool)] = []
        var nextIsSentenceStart = true
        for raw in rawTokens.flatMap(splitGluedCommand) {
            let (word, endedSentence) = stripModelPunctuation(raw)
            if !word.isEmpty {
                tokens.append((word, nextIsSentenceStart))
                nextIsSentenceStart = false
            }
            if endedSentence { nextIsSentenceStart = true }
        }

        // 2. Turn spoken punctuation words into symbols.
        var pieces: [Piece] = []
        var i = 0
        while i < tokens.count {
            let lower = tokens[i].word.lowercased()
            if lower == literalPrefix, i + 1 < tokens.count,
               let command = matchCommand(in: tokens, at: i + 1) {
                for k in 0..<command.words.count {
                    let token = tokens[i + 1 + k]
                    pieces.append(.word(token.word, wasSentenceStart: token.wasSentenceStart))
                }
                i += 1 + command.words.count
                continue
            }
            if let command = matchCommand(in: tokens, at: i) {
                pieces.append(.symbol(command.symbol, command.attach, endsSentence: command.endsSentence))
                i += command.words.count
                continue
            }
            pieces.append(.word(tokens[i].word, wasSentenceStart: tokens[i].wasSentenceStart))
            i += 1
        }

        // 3. Fix capitalization and join.
        var output = ""
        var glueNext = true            // no space before the next piece
        var capitalizeNext = capitalizeFirstWord
        var isFirstWord = true
        for piece in pieces {
            switch piece {
            case let .word(word, wasSentenceStart):
                var w = word
                if capitalizeNext {
                    w = capitalizingFirstLetter(w)
                } else if wasSentenceStart || isFirstWord {
                    // The model capitalized this only because it began a
                    // sentence the user never ended. Undo that unless it's a
                    // word that is always capitalized.
                    if !isAlwaysCapitalized(w, properNouns: properNouns) {
                        w = lowercasingFirstLetter(w)
                    }
                }
                if !glueNext { output += " " }
                output += w
                glueNext = false
                capitalizeNext = false
                isFirstWord = false
            case let .symbol(symbol, attach, endsSentence):
                switch attach {
                case .left, .both, .lineBreak:
                    while output.hasSuffix(" ") { output.removeLast() }
                case .right, .spaced:
                    if !glueNext { output += " " }
                }
                output += symbol
                glueNext = (attach == .right || attach == .both || attach == .lineBreak)
                if endsSentence { capitalizeNext = true }
            }
        }
        return output
    }

    /// Normal mode (spoken punctuation off): text dictated into the middle of
    /// a sentence shouldn't arrive as "Short." — lowercase the first word
    /// unless it's always capitalized, and drop the model's final period.
    static func fitMidSentence(_ text: String) -> String {
        var result = text
        if result.hasSuffix("."), !result.hasSuffix(".."),
           let lastWord = result.split(separator: " ").last,
           lastWord.range(of: #"^([A-Za-z]\.){2,}$"#, options: .regularExpression) == nil {
            result.removeLast()
        }
        guard let firstWord = result.split(whereSeparator: { $0.isWhitespace }).first else { return result }
        let (bare, _) = stripModelPunctuation(String(firstWord))
        if !isAlwaysCapitalized(bare, properNouns: namedEntities(in: text)) {
            result = lowercasingFirstLetter(result)
        }
        return result
    }

    private static func matchCommand(in tokens: [(word: String, wasSentenceStart: Bool)], at index: Int) -> Command? {
        for command in commands where index + command.words.count <= tokens.count {
            var matches = true
            for (offset, expected) in command.words.enumerated()
            where tokens[index + offset].word.lowercased() != expected {
                matches = false
                break
            }
            if matches { return command }
        }
        return nil
    }

    /// The model sometimes hyphenates a command onto the previous word
    /// ("at three period" → "three-period").
    private static func splitGluedCommand(_ token: String) -> [String] {
        guard let dash = token.lastIndex(of: "-") else { return [token] }
        let tail = String(token[token.index(after: dash)...])
        let (bare, _) = stripModelPunctuation(tail)
        let singleWordCommands = commands.filter { $0.words.count == 1 }.map { $0.words[0] }
        guard singleWordCommands.contains(bare.lowercased()), dash != token.startIndex else { return [token] }
        return [String(token[..<dash]), tail]
    }

    /// Strips punctuation the speech model attached to a token, keeping
    /// punctuation inside it ("don't", "3.5%", "1,200", "well-known", "U.S.").
    private static func stripModelPunctuation(_ token: String) -> (String, endedSentence: Bool) {
        if token.range(of: #"^([A-Za-z]\.){2,}$"#, options: .regularExpression) != nil {
            return (token, false)
        }
        var scalars = Substring(token).unicodeScalars
        var endedSentence = false
        while let last = scalars.last, trailingStrip.contains(last) {
            if sentenceEnders.contains(last) { endedSentence = true }
            scalars.removeLast()
        }
        while let first = scalars.first, leadingStrip.contains(first) {
            scalars.removeFirst()
        }
        return (String(scalars), endedSentence)
    }

    // MARK: - Parakeet token timings

    struct TimedToken {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
    }

    private static let punctuationWords: [String: String] = [
        ",": "comma", ".": "period", "?": "question mark", "!": "exclamation point",
        ":": "colon", ";": "semicolon",
    ]

    /// Parakeet sometimes writes a spoken "comma" as "," itself, which would
    /// then be stripped as model punctuation. A mark the model inferred takes
    /// one ~80 ms frame; one it transcribed from speech spans the spoken word.
    /// Marks that span speech are turned back into their words so `process`
    /// keeps them. A long mark over silence (a pause) stays inferred.
    ///
    /// Returns nil when timings can't be used; callers keep the model text.
    static func restoreSpokenPunctuationWords(tokens: [TimedToken], samples: [Float], sampleRate: Double = 16000) -> String? {
        guard !tokens.isEmpty, !samples.isEmpty else { return nil }

        func peakLevel(_ token: TimedToken) -> Float {
            let window = Int(0.04 * sampleRate)
            let from = max(0, Int(token.start * sampleRate))
            let to = min(samples.count, Int(token.end * sampleRate))
            guard to - from >= window else { return 0 }
            var peak: Float = 0
            var i = from
            while i + window <= to {
                var sum: Float = 0
                for j in i..<(i + window) { sum += samples[j] * samples[j] }
                peak = max(peak, (sum / Float(window)).squareRoot())
                i += window / 2
            }
            return peak
        }

        let wordLevels = tokens
            .filter { $0.text.contains(where: { $0.isLetter || $0.isNumber }) }
            .map(peakLevel)
            .filter { $0 > 0 }
            .sorted()
        guard !wordLevels.isEmpty else { return nil }
        let speechLevel = wordLevels[wordLevels.count / 2]

        var text = ""
        for (index, token) in tokens.enumerated() {
            let mark = token.text.trimmingCharacters(in: .whitespaces)
            // "1,200" and "3.5": a mark between digits is part of the number.
            let previous = index > 0 ? tokens[index - 1].text : ""
            let next = index + 1 < tokens.count ? tokens[index + 1].text : ""
            let insideNumber = previous.last?.isNumber == true && next.first?.isNumber == true
            if let word = punctuationWords[mark], !insideNumber,
               token.end - token.start >= 0.2,
               peakLevel(token) >= speechLevel * 0.3 {
                text += " \(word) "
            } else {
                text += token.text
            }
        }
        return text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func isAlwaysCapitalized(_ word: String, properNouns: Set<String>) -> Bool {
        if word == "I" || word.hasPrefix("I'") || word.hasPrefix("I’") { return true }
        // Acronyms such as "NASA" or "PDF".
        if word.count > 1, word == word.uppercased(), word.contains(where: { $0.isLetter }) { return true }
        return properNouns.contains(word)
    }

    /// Names, places and organisations, as tagged by NaturalLanguage.
    private static func namedEntities(in text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var names = Set<String>()
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                names.insert(String(text[range]))
            }
            return true
        }
        return names
    }

    private static func capitalizingFirstLetter(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    private static func lowercasingFirstLetter(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.lowercased() + word.dropFirst()
    }
}
