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

struct Attachment: Codable, Hashable {
    let id: String
    let url: URL
    let type: AttachmentType
    let name: String
    let downloadURL: URL?
}

enum AttachmentType: String, Codable, Hashable {
    case image
    case file
}

struct UnifiedMessage: Identifiable, Codable, Hashable {
    let id: String
    let body: String
    let sender: User
    let timestamp: Date
    let service: MessageService
    let channelName: String?
    let attachments: [Attachment]
    
    init(id: String, body: String, sender: User, timestamp: Date, service: MessageService, channelName: String?, attachments: [Attachment] = []) {
        self.id = id
        self.body = body
        self.sender = sender
        self.timestamp = timestamp
        self.service = service
        self.channelName = channelName
        self.attachments = attachments
    }
    
    // Helper for preview
    static let example = UnifiedMessage(
        id: "1",
        body: "Hello, this is a test message.",
        sender: User(id: "u1", name: "Alice", avatarURL: nil, service: .slack),
        timestamp: Date(),
        service: .slack,
        channelName: "general",
        attachments: []
    )
}
