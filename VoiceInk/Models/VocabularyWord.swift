import Foundation
import SwiftData

@Model
final class VocabularyWord {
    @Attribute(.unique) var word: String
    var dateAdded: Date

    init(word: String, dateAdded: Date = Date()) {
        self.word = word
        self.dateAdded = dateAdded
    }
}
