import Foundation
import SwiftUI

@MainActor
class MessageListViewModel: ObservableObject {
    @Published var messages: [UnifiedMessage] = []
    @Published var isLoading = false
    @Published var selectedService: MessageService? = .slack {
        didSet {
            selectedChannel = nil
        }
    }
    
    @Published var channels: [Channel] = []
    @Published var selectedChannel: Channel?
    
    private var services: [MessageService: MessengerServiceProtocol] = [:]
    private var channelNames: [String: String] = [:] // Cache: ID -> Name
    
    init() {
        self.services = [
            .slack: SlackService(
                appToken: Secrets.slackAppToken,
                botToken: Secrets.slackBotToken
            ),
            .chatwork: ChatworkService(apiToken: "mock"),
            .googleChat: GoogleChatService()
        ]
    }
    
    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        var allMessages: [UnifiedMessage] = []
        
        for (_, service) in services {
            do {
                let msgs = try await service.fetchMessages()
                allMessages.append(contentsOf: msgs)
            } catch {
                print("Error fetching messages: \(error)")
            }
        }
        
        // Sort by timestamp ascending (Oldest first)
        self.messages = allMessages.sorted(by: { $0.timestamp < $1.timestamp })
        
        // Fetch Channels explicitly
        var allChannels: [Channel] = []
        for (_, service) in services {
            if let channels = try? await service.fetchChannels() {
                allChannels.append(contentsOf: channels)
            }
        }
        
        await MainActor.run {
            self.channels = allChannels
        }
        
        // Extract initial channels from messages (backup/merge)
        // await updateChannels(from: self.messages)
        
        // Subscribe to streams
        for (_, service) in services {
            Task {
                for await message in service.messageStream {
                    await MainActor.run {
                        self.messages.append(message) // Append to end
                        self.messages.sort(by: { $0.timestamp < $1.timestamp }) // Re-sort just in case
                    }
                    await self.updateChannels(from: [message])
                }
            }
        }
    }
    
    private func updateChannels(from newMessages: [UnifiedMessage]) async {
        for message in newMessages {
            guard let channelId = message.channelName else { continue }
            
            // Check cache or fetch
            var name = channelNames[channelId]
            if name == nil {
                // Fetch name
                if let service = services[message.service] {
                    name = try? await service.fetchChannelName(channelId: channelId)
                    if let fetchedName = name {
                        channelNames[channelId] = fetchedName
                    }
                }
            }
            
            let displayName = name ?? channelId
            let isDM = channelId.starts(with: "D") // Slack DMs start with D
            
            print("DEBUG: Discovered channel: \(displayName) (ID: \(channelId), isDM: \(isDM))")
            
            let channel = Channel(id: channelId, name: displayName, service: message.service, isDM: isDM)
            
            // Update channels list if needed
            if let index = channels.firstIndex(where: { $0.id == channel.id && $0.service == channel.service }) {
                // Update name if changed (e.g. from ID to Name)
                if channels[index].name != channel.name {
                    channels[index] = channel
                }
            } else {
                channels.append(channel)
            }
        }
    }
    
    var filteredMessages: [UnifiedMessage] {
        var result = messages
        
        // 1. Filter by Service
        if let service = selectedService {
            result = result.filter { $0.service == service }
        }
        
        // 2. Filter by Channel
        if let channel = selectedChannel {
            result = result.filter { $0.channelName == channel.id }
        }
        
        return result
    }
    
    var filteredChannels: [Channel] {
        guard let service = selectedService else { return [] }
        return channels.filter { $0.service == service && !$0.isDM }
    }
    
    var filteredDMs: [Channel] {
        guard let service = selectedService else { return [] }
        return channels.filter { $0.service == service && $0.isDM }
    }
    
    // MARK: - Sending
    
    @Published var messageText: String = ""
    
    func sendMessage() async {
        guard let serviceType = selectedService,
              let channel = selectedChannel,
              !messageText.isEmpty,
              let service = services[serviceType] else { return }
        
        let textToSend = messageText
        messageText = "" // Clear input immediately
        
        do {
            try await service.sendMessage(body: textToSend, to: channel.id)
            // Note: We don't manually append the message here because we expect it to come back via the WebSocket stream
        } catch {
            print("Failed to send message: \(error)")
            // TODO: Restore text or show error
        }
    }
    
    func uploadFile(url: URL) async {
        guard let serviceType = selectedService,
              let channel = selectedChannel,
              let service = services[serviceType] else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let mimetype = "application/octet-stream" // Simplification
            
            try await service.uploadFile(data: data, filename: filename, mimetype: mimetype, to: channel.id)
        } catch {
            print("Failed to upload file: \(error)")
        }
    }
}


