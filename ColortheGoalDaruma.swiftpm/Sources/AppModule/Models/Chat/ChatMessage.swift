import Foundation

enum ChatSender {
    case system
    case assistant
    case user
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let sender: ChatSender
    let text: String
    let timestamp: Date

    init(sender: ChatSender, text: String, timestamp: Date = .init()) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}
