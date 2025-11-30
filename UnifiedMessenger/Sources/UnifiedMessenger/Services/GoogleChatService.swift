import Foundation

class GoogleChatService: MessengerServiceProtocol {
    
    var messageStream: AsyncStream<UnifiedMessage> {
        AsyncStream { _ in } // No real stream for mock
    }
    
    func fetchMessages() async throws -> [UnifiedMessage] {
        return [
            UnifiedMessage(
                id: UUID().uuidString,
                body: "Meeting starting in 5 mins",
                sender: User(id: "g1", name: "Google User", avatarURL: nil, service: .googleChat),
                timestamp: Date(),
                service: .googleChat,
                channelName: "Team Updates"
            ),
            UnifiedMessage(
                id: UUID().uuidString,
                body: "Did you see the doc?",
                sender: User(id: "g2", name: "Manager", avatarURL: nil, service: .googleChat),
                timestamp: Date().addingTimeInterval(-3600),
                service: .googleChat,
                channelName: "Project X"
            )
        ]
    }
    
    func sendMessage(body: String, to roomId: String) async throws {
        // Mock send
    }
    
    func fetchChannelName(channelId: String) async throws -> String {
        return "Space \(channelId)" // Mock
    }
}
