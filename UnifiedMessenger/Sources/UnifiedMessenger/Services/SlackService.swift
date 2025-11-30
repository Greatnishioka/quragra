import Foundation

// MARK: - Slack API Models

struct SlackConnectResponse: Codable {
    let ok: Bool
    let url: String?
    let error: String?
}

struct SlackEnvelope: Codable {
    let envelope_id: String?
    let type: String // "events_api", "disconnect", "hello", etc.
    let payload: SlackPayload?
}

struct SlackPayload: Codable {
    let event: SlackEvent?
}

struct SlackEvent: Codable {
    let type: String
    let text: String?
    let user: String?
    let channel: String?
    let ts: String?
    let subtype: String?
}

struct SlackChannelResponse: Codable {
    let ok: Bool
    let channel: SlackChannelInfo?
    let error: String?
}

struct SlackChannelInfo: Codable {
    let id: String
    let name: String
}

struct SlackConversationsResponse: Codable {
    let ok: Bool
    let channels: [SlackChannelInfo]?
    let error: String?
}

struct SlackHistoryResponse: Codable {
    let ok: Bool
    let messages: [SlackEvent]?
    let error: String?
}

// MARK: - Service

class SlackService: MessengerServiceProtocol, ObservableObject {
    private let appToken: String
    private let botToken: String
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    
    @Published var receivedMessages: [UnifiedMessage] = []
    
    // Stream support
    private var messageContinuation: AsyncStream<UnifiedMessage>.Continuation?
    lazy var messageStream: AsyncStream<UnifiedMessage> = {
        AsyncStream { continuation in
            self.messageContinuation = continuation
        }
    }()
    
    init(appToken: String, botToken: String) {
        self.appToken = appToken
        self.botToken = botToken
    }
    
    func connect() async throws {
        // 1. Get WebSocket URL
        guard let url = URL(string: "https://slack.com/api/apps.connections.open") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(SlackConnectResponse.self, from: data)
        
        guard let wssURLString = response.url, let wssURL = URL(string: wssURLString) else {
            print("Error getting Slack WSS URL: \(response.error ?? "Unknown error")")
            return
        }
        
        print("Slack WSS URL: \(wssURL)")
        
        // 2. Connect WebSocket
        webSocketTask = session.webSocketTask(with: wssURL)
        webSocketTask?.resume()
        
        // 3. Start Listening
        listen()
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("Slack WebSocket Error: \(error)")
                // TODO: Reconnect logic
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.listen()
            }
        }
    }
    
    private func handleMessage(_ jsonString: String) {
        print("DEBUG: Received JSON: \(jsonString)") // Debug log
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let envelope = try JSONDecoder().decode(SlackEnvelope.self, from: data)
            
            // 0. Handle Hello
            if envelope.type == "hello" {
                print("Slack: Connected successfully (Hello received)")
                return
            }
            
            // 1. Acknowledge immediately if ID exists
            if let envelopeId = envelope.envelope_id {
                sendAck(envelopeId: envelopeId)
            }
            
            // 2. Process Event
            if envelope.type == "events_api",
               let event = envelope.payload?.event,
               event.type == "message",
               let text = event.text,
               let userId = event.user,
               let ts = event.ts {
                
                // Convert to UnifiedMessage
                let message = UnifiedMessage(
                    id: ts, // Use timestamp as ID for now
                    body: text,
                    sender: User(id: userId, name: "User \(userId.prefix(4))", avatarURL: nil, service: .slack),
                    timestamp: Date(timeIntervalSince1970: Double(ts) ?? 0),
                    service: .slack,
                    channelName: event.channel
                )
                
                DispatchQueue.main.async {
                    self.receivedMessages.append(message)
                    self.messageContinuation?.yield(message) // Yield to stream
                    print("Received Slack Message: \(text)")
                }
            }
            
        } catch {
            print("Error parsing Slack envelope: \(error)")
            print("Raw JSON: \(jsonString)")
        }
    }
    
    private func sendAck(envelopeId: String) {
        let ack = ["envelope_id": envelopeId]
        if let data = try? JSONEncoder().encode(ack),
           let jsonString = String(data: data, encoding: .utf8) {
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Error sending ACK: \(error)")
                }
            }
        }
    }
    
    func fetchMessages() async throws -> [UnifiedMessage] {
        // For MVP, if we haven't connected yet, try to connect.
        if webSocketTask == nil && appToken != "mock" {
            try await connect()
        }
        
        if appToken == "mock" {
             return [
                UnifiedMessage(
                    id: UUID().uuidString,
                    body: "Mock Slack Message via Socket Mode",
                    sender: User(id: "s1", name: "Slack User", avatarURL: nil, service: .slack),
                    timestamp: Date(),
                    service: .slack,
                    channelName: "#random"
                )
            ]
        }
        
        // Fetch history from joined channels
        var historyMessages: [UnifiedMessage] = []
        do {
            let channels = try await fetchJoinedChannels()
            for channel in channels {
                let messages = try await fetchHistory(channelId: channel.id)
                historyMessages.append(contentsOf: messages)
            }
        } catch {
            print("Error fetching history: \(error)")
        }
        
        return historyMessages + receivedMessages
    }
    
    func sendMessage(body: String, to channelId: String) async throws {
        // Call chat.postMessage
    }
    
    func fetchChannelName(channelId: String) async throws -> String {
        guard let url = URL(string: "https://slack.com/api/conversations.info?channel=\(channelId)") else { return channelId }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(SlackChannelResponse.self, from: data)
        
        if let name = response.channel?.name {
            return name
        } else {
            print("Error fetching channel name for \(channelId): \(response.error ?? "Unknown")")
            return channelId
        }
    }
    
    private func fetchJoinedChannels() async throws -> [SlackChannelInfo] {
        guard let url = URL(string: "https://slack.com/api/users.conversations?types=public_channel,private_channel") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(SlackConversationsResponse.self, from: data)
        
        if let channels = response.channels {
            return channels
        } else {
            print("Error fetching joined channels: \(response.error ?? "Unknown")")
            return []
        }
    }
    
    private func fetchHistory(channelId: String) async throws -> [UnifiedMessage] {
        guard let url = URL(string: "https://slack.com/api/conversations.history?channel=\(channelId)&limit=20") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(SlackHistoryResponse.self, from: data)
        
        guard let events = response.messages else {
            print("Error fetching history for \(channelId): \(response.error ?? "Unknown")")
            return []
        }
        
        return events.compactMap { event in
            guard let text = event.text, let userId = event.user, let ts = event.ts else { return nil }
            
            return UnifiedMessage(
                id: ts,
                body: text,
                sender: User(id: userId, name: "User \(userId.prefix(4))", avatarURL: nil, service: .slack),
                timestamp: Date(timeIntervalSince1970: Double(ts) ?? 0),
                service: .slack,
                channelName: channelId // History messages don't have channel inside, so use the requested ID
            )
        }
    }
}
