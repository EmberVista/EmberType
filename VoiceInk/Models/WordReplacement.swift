import Foundation
import SwiftData

@Model
final class WordReplacement {
    var id: UUID
    var originalText: String
    var replacementText: String
    var dateAdded: Date
    var isEnabled: Bool

    init(originalText: String, replacementText: String, dateAdded: Date = Date(), isEnabled: Bool = true) {
        self.id = UUID()
        self.originalText = originalText
        self.replacementText = replacementText
        self.dateAdded = dateAdded
        self.isEnabled = isEnabled
    }
}
