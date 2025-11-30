import Foundation

protocol MessengerServiceProtocol {
    func fetchMessages() async throws -> [UnifiedMessage]
    func fetchChannels() async throws -> [Channel]
    func sendMessage(body: String, to roomId: String) async throws
    func uploadFile(data: Data, filename: String, mimetype: String, to roomId: String) async throws
    var messageStream: AsyncStream<UnifiedMessage> { get }
    func fetchChannelName(channelId: String) async throws -> String
}
