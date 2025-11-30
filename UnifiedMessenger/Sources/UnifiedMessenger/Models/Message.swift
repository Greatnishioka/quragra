import Foundation

enum MessageService: String, Codable, CaseIterable {
    case slack
    case chatwork
    case googleChat
}

struct User: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let avatarURL: URL?
    let service: MessageService
}

struct UnifiedMessage: Identifiable, Codable, Hashable {
    let id: String
    let body: String
    let sender: User
    let timestamp: Date
    let service: MessageService
    let channelName: String?
    
    // Helper for preview
    static let example = UnifiedMessage(
        id: "1",
        body: "Hello, this is a test message.",
        sender: User(id: "u1", name: "Alice", avatarURL: nil, service: .slack),
        timestamp: Date(),
        service: .slack,
        channelName: "general"
    )
}
