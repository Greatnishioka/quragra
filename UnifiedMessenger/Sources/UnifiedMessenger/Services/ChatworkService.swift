import Foundation

protocol MessengerServiceProtocol {
    func fetchMessages() async throws -> [UnifiedMessage]
    func sendMessage(body: String, to roomId: String) async throws
    var messageStream: AsyncStream<UnifiedMessage> { get }
    func fetchChannelName(channelId: String) async throws -> String
}

class ChatworkService: MessengerServiceProtocol {
    private let apiToken: String
    private let baseURL = URL(string: "https://api.chatwork.com/v2")!
    
    // Stream support
    private var messageContinuation: AsyncStream<UnifiedMessage>.Continuation?
    lazy var messageStream: AsyncStream<UnifiedMessage> = {
        AsyncStream { continuation in
            self.messageContinuation = continuation
        }
    }()
    
    init(apiToken: String) {
        self.apiToken = apiToken
    }
    
    func fetchMessages() async throws -> [UnifiedMessage] {
        // Placeholder: In a real app, we would iterate over rooms or fetch from a specific room.
        // For this MVP, let's assume we fetch from a hardcoded room or just return mock data if token is empty.
        
        if apiToken == "mock" {
            return [
                UnifiedMessage(
                    id: UUID().uuidString,
                    body: "Mock Chatwork Message",
                    sender: User(id: "cw1", name: "Chatwork User", avatarURL: nil, service: .chatwork),
                    timestamp: Date(),
                    service: .chatwork,
                    channelName: "General"
                )
            ]
        }
        
        // TODO: Implement actual API call
        // GET /rooms/{room_id}/messages
        return []
    }
    
    func sendMessage(body: String, to roomId: String) async throws {
        // TODO: Implement sending
    }
    
    func fetchChannelName(channelId: String) async throws -> String {
        return "Room \(channelId)" // Mock
    }
}
