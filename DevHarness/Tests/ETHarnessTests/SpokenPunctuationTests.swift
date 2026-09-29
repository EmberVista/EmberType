import XCTest
@testable import ETHarness

/// Inputs are shaped like real Parakeet output (see corpus/ results):
/// the model capitalizes, ends with a period, and writes punctuation as words.
final class SpokenPunctuationTests: XCTestCase {
    private func mid(_ s: String) -> String { SpokenPunctuationProcessor.process(s, capitalizeFirstWord: false) }
    private func start(_ s: String) -> String { SpokenPunctuationProcessor.process(s, capitalizeFirstWord: true) }

    // Customer report: inserting a word gave "Take this Short. sentence".
    func testInsertedWordIsLowercaseWithNoPeriod() {
        XCTAssertEqual(mid("Short."), "short")
        XCTAssertEqual(mid("All of my."), "all of my")
    }

    func testProperNounsAndIKeepTheirCapital() {
        XCTAssertEqual(mid("And Sarah from accounting."), "and Sarah from accounting")
        XCTAssertEqual(mid("I think so."), "I think so")
        XCTAssertEqual(mid("I'm here."), "I'm here")
        XCTAssertEqual(mid("NASA launched it."), "NASA launched it")
        XCTAssertEqual(mid("The U.S. economy."), "the U.S. economy")
    }

    // Customer request: no inferred punctuation at all.
    func testInferredPunctuationIsRemoved() {
        XCTAssertEqual(mid("Is this working?"), "is this working")
        XCTAssertEqual(start("Is this working?"), "Is this working")
        XCTAssertEqual(start("I went to the store. Then I came home. It was a long day."),
                       "I went to the store then I came home it was a long day")
        XCTAssertEqual(mid("Don't worry, it's fine."), "don't worry it's fine")
    }

    func testInternalPunctuationIsKept() {
        XCTAssertEqual(start("We sold 1,200 units at 3.5% margin."), "We sold 1,200 units at 3.5% margin")
        XCTAssertEqual(mid("It was a well-known fact."), "it was a well-known fact")
    }

    func testSpokenPunctuation() {
        XCTAssertEqual(start("Hello comma how are you question mark."), "Hello, how are you?")
        XCTAssertEqual(start("Please send the report by Friday exclamation point."), "Please send the report by Friday!")
        XCTAssertEqual(start("That is all full stop."), "That is all.")
        XCTAssertEqual(start("Dear Sam colon thanks for the note period."), "Dear Sam: thanks for the note.")
        XCTAssertEqual(start("I use semicolons semicolon colons colon and dashes."), "I use semicolons; colons: and dashes")
        XCTAssertEqual(start("Semi colon."), ";")
        XCTAssertEqual(start("Wait em dash never mind."), "Wait—never mind")
        XCTAssertEqual(start("A hyphen B."), "A-B")
        XCTAssertEqual(start("Well ellipsis maybe."), "Well... maybe")
    }

    // Customer request: semicolons, colons, parentheses, quotes.
    func testBracketsAndQuotes() {
        XCTAssertEqual(start("The budget open paren see attached close paren is final period."),
                       "The budget (see attached) is final.")
        XCTAssertEqual(start("She said open quote hello close quote and left period."),
                       "She said \"hello\" and left.")
    }

    func testSentenceEndCapitalizesNextWord() {
        XCTAssertEqual(start("The meeting is at 3 period we will discuss the budget comma the timeline comma and staffing period."),
                       "The meeting is at 3. We will discuss the budget, the timeline, and staffing.")
        XCTAssertEqual(mid("Then I realized I was wrong period."), "then I realized I was wrong.")
    }

    // Customer request: "new paragraph" / "new line".
    func testLineBreaks() {
        XCTAssertEqual(start("First line new line second line new paragraph third paragraph"),
                       "First line\nSecond line\n\nThird paragraph")
    }

    // The model sometimes punctuates around the command words themselves.
    func testCommandsSurroundedByModelPunctuation() {
        XCTAssertEqual(start("Hello comma, how are you? Question mark."), "Hello, how are you?")
        XCTAssertEqual(mid("Period."), ".")
    }

    func testLiteralEscape() {
        XCTAssertEqual(start("The trial literal period lasts seven days period."), "The trial period lasts seven days.")
        XCTAssertEqual(start("Use a literal comma splice."), "Use a comma splice")
    }

    // Owner voice test: "choose Edit > Start Dictation".
    func testSymbols() {
        XCTAssertEqual(start("Press the shortcut or choose Edit greater than sign Start Dictation Period."),
                       "Press the shortcut or choose Edit > Start Dictation.")
        XCTAssertEqual(mid("Costs greater than expected."), "costs greater than expected")
        XCTAssertEqual(mid("Please read and sign the form."), "please read and sign the form")
        XCTAssertEqual(start("A less than sign B."), "A < B")
    }

    func testSingleQuotes() {
        XCTAssertEqual(start("He called it open single quote fine close single quote period."), "He called it 'fine'.")
    }

    // Normal mode: "Take this Short. sentence" (customer report).
    func testFitMidSentence() {
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("Short."), "short")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("All of my."), "all of my")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("I think."), "I think")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("Sarah said so."), "Sarah said so")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("Really?"), "really?")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("In the U.S."), "in the U.S.")
        XCTAssertEqual(SpokenPunctuationProcessor.fitMidSentence("Wait..."), "wait...")
    }

    func testEmptyInput() {
        XCTAssertEqual(mid(""), "")
        XCTAssertEqual(start("   "), "")
    }
}

final class CursorContextTests: XCTestCase {
    func testPosition() {
        XCTAssertEqual(CursorContextService.position(after: nil), .unknown)
        XCTAssertEqual(CursorContextService.position(after: ""), .sentenceStart)
        XCTAssertEqual(CursorContextService.position(after: "Done. "), .sentenceStart)
        XCTAssertEqual(CursorContextService.position(after: "Really?"), .sentenceStart)
        XCTAssertEqual(CursorContextService.position(after: "Line one\n"), .sentenceStart)
        XCTAssertEqual(CursorContextService.position(after: "He said \"Hi.\" "), .sentenceStart)
        XCTAssertEqual(CursorContextService.position(after: "Take this "), .midSentence)
        XCTAssertEqual(CursorContextService.position(after: "Dear Sam,"), .midSentence)
    }

    func testLeadingSpace() {
        XCTAssertTrue(CursorContextService.needsLeadingSpace(before: "Take this", text: "short"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: "Take this ", text: "short"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: "Hello", text: ", there"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: "(", text: "see"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: "", text: "short"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: nil, text: "short"))
        XCTAssertFalse(CursorContextService.needsLeadingSpace(before: "End.", text: "\n\nNext"))
    }

    func testTrailingSpace() {
        XCTAssertTrue(CursorContextService.needsTrailingSpace(after: nil, text: "short"))
        XCTAssertTrue(CursorContextService.needsTrailingSpace(after: "", text: "short"))
        XCTAssertTrue(CursorContextService.needsTrailingSpace(after: "s", text: "short"))
        XCTAssertFalse(CursorContextService.needsTrailingSpace(after: " ", text: "short"))
        XCTAssertFalse(CursorContextService.needsTrailingSpace(after: ",", text: "short"))
        XCTAssertFalse(CursorContextService.needsTrailingSpace(after: "", text: "one\n"))
    }
}

final class TokenTimingTests: XCTestCase {
    private typealias T = SpokenPunctuationProcessor.TimedToken

    /// 16 kHz audio with "speech" (a tone) in the given spans and silence elsewhere.
    private func audio(seconds: Double, speech: [(Double, Double)]) -> [Float] {
        var samples = [Float](repeating: 0, count: Int(seconds * 16000))
        for (from, to) in speech {
            for i in Int(from * 16000)..<Int(to * 16000) { samples[i] = 0.3 * sin(Float(i) * 0.1) }
        }
        return samples
    }

    // Parakeet wrote a spoken "comma" as "," spanning the spoken word.
    func testSpokenCommaIsRestored() {
        let tokens = [T(text: " budget", start: 0.0, end: 0.4), T(text: ",", start: 0.4, end: 0.9), T(text: " the", start: 0.9, end: 1.1)]
        let samples = audio(seconds: 1.2, speech: [(0.0, 1.1)])
        XCTAssertEqual(SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: tokens, samples: samples), "budget comma the")
    }

    // Inferred comma: one frame long.
    func testInferredCommaIsLeftAlone() {
        let tokens = [T(text: " budget", start: 0.0, end: 0.4), T(text: ",", start: 0.4, end: 0.48), T(text: " the", start: 0.48, end: 0.7)]
        let samples = audio(seconds: 0.8, speech: [(0.0, 0.7)])
        XCTAssertEqual(SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: tokens, samples: samples), "budget, the")
    }

    // A thinking pause makes a long inferred comma over silence.
    func testLongCommaOverSilenceIsLeftAlone() {
        let tokens = [T(text: " budget", start: 0.0, end: 0.4), T(text: ",", start: 0.4, end: 1.4), T(text: " the", start: 1.4, end: 1.6)]
        let samples = audio(seconds: 1.7, speech: [(0.0, 0.4), (1.4, 1.6)])
        XCTAssertEqual(SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: tokens, samples: samples), "budget, the")
    }

    func testNumbersAreLeftAlone() {
        let tokens = [T(text: " 1", start: 0.0, end: 0.3), T(text: ",", start: 0.3, end: 0.8), T(text: "200", start: 0.8, end: 1.2)]
        let samples = audio(seconds: 1.3, speech: [(0.0, 1.2)])
        XCTAssertEqual(SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: tokens, samples: samples), "1,200")
    }

    func testNoTimingsReturnsNil() {
        XCTAssertNil(SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: [], samples: [0.1]))
    }
}
