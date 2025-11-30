import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MessageListViewModel()
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Sidebar (Service Selector)
            SidebarView(selectedService: $viewModel.selectedService)
                .frame(width: 60)
            
            // 2. Channel List
            ChannelListView(viewModel: viewModel)
                .frame(width: 250)
            
            // 3. Message Area
            MessageAreaView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadMessages()
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

// MARK: - Subviews

struct SidebarView: View {
    @Binding var selectedService: MessageService?
    
    var body: some View {
        VStack(spacing: 0) {
            ServiceTabButton(service: .slack, color: Color(red: 0.28, green: 0.65, blue: 0.60), selected: $selectedService)
            ServiceTabButton(service: .chatwork, color: Color(red: 0.22, green: 0.24, blue: 0.26), selected: $selectedService)
            ServiceTabButton(service: .googleChat, color: Color(red: 0.93, green: 0.45, blue: 0.25), selected: $selectedService)
        }
    }
}

struct ServiceTabButton: View {
    let service: MessageService
    let color: Color
    @Binding var selected: MessageService?
    
    var body: some View {
        Text(serviceName)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .rotationEffect(.degrees(-90))
            .fixedSize()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
            .contentShape(Rectangle())
            .onTapGesture {
                selected = service
            }
    }
    
    var serviceName: String {
        switch service {
        case .slack: return "Slack"
        case .chatwork: return "ChatWork"
        case .googleChat: return "Google Chat"
        }
    }
}

struct ChannelListView: View {
    @ObservedObject var viewModel: MessageListViewModel
    
    var body: some View {
        ZStack {
            backgroundColor
            
            VStack {
                if let service = viewModel.selectedService {
                    Text(serviceName(for: service))
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if !viewModel.filteredChannels.isEmpty {
                                Text("Channels")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.filteredChannels) { channel in
                                    ChannelRow(channel: channel, isSelected: viewModel.selectedChannel?.id == channel.id) {
                                        viewModel.selectedChannel = channel
                                    }
                                }
                            }
                            
                            if !viewModel.filteredDMs.isEmpty {
                                Text("Direct Messages")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                
                                ForEach(viewModel.filteredDMs) { channel in
                                    ChannelRow(channel: channel, isSelected: viewModel.selectedChannel?.id == channel.id) {
                                        viewModel.selectedChannel = channel
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("Select Service")
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
    }
    
    private func serviceName(for service: MessageService) -> String {
        switch service {
        case .slack: return "Slack"
        case .chatwork: return "ChatWork"
        case .googleChat: return "Google Chat"
        }
    }
    
    private var backgroundColor: Color {
        switch viewModel.selectedService {
        case .slack: return Color(red: 0.2, green: 0.6, blue: 0.5) // Slack Green
        case .chatwork: return Color(red: 0.8, green: 0.2, blue: 0.2) // Chatwork Red
        case .googleChat: return Color(red: 0.2, green: 0.6, blue: 0.3) // Google Green
        case .none: return Color.gray
        }
    }
}

struct ChannelRow: View {
    let channel: Channel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: channel.isDM ? "person.circle.fill" : "number")
                    .foregroundColor(.white.opacity(0.7))
                Text(channel.name)
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.8))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                ? Color.white.opacity(0.3)
                : Color.white.opacity(0.1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MessageAreaView: View {
    @ObservedObject var viewModel: MessageListViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.selectedChannel?.name ?? "Select a Channel")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredMessages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .background(Color(red: 0.96, green: 0.93, blue: 0.88)) // Beige background
            
            // Input Area
            HStack {
                Button(action: {
                    openFilePicker()
                }) {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    openFilePicker()
                }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                TextField("Message...", text: $viewModel.messageText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .onSubmit {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                
                Button(action: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.messageText.isEmpty)
            }
            .padding()
            .background(Color.white)
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.uploadFile(url: url)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: UnifiedMessage
    
    var body: some View {
        HStack(alignment: .top) {
            if !isMe {
                // Avatar
                Circle()
                    .fill(Color.gray)
                    .frame(width: 32, height: 32)
                    .overlay(Text(message.sender.name.prefix(1)).foregroundColor(.white).font(.caption))
            }
            
            VStack(alignment: isMe ? .trailing : .leading) {
                if !isMe {
                    Text(message.sender.name)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if !message.body.isEmpty {
                    Text(message.body)
                        .padding(12)
                        .background(isMe ? Color.blue.opacity(0.1) : Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 1)
                }
                
                // Attachments
                ForEach(message.attachments, id: \.self) { attachment in
                    if attachment.type == .image {
                        if message.service == .slack {
                            SecureImage(url: attachment.url, token: Secrets.slackBotToken)
                                .frame(maxWidth: 300, maxHeight: 300)
                                .cornerRadius(8)
                        } else {
                            AsyncImage(url: attachment.url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .frame(maxWidth: 300, maxHeight: 300)
                                         .cornerRadius(8)
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    } else {
                        // File
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.gray)
                            Text(attachment.name)
                                .foregroundColor(.primary)
                            if let downloadURL = attachment.downloadURL {
                                Link(destination: downloadURL) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 1)
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if isMe {
                Spacer()
            } else {
                Spacer()
            }
        }
    }
    
    private func serviceName(for service: MessageService) -> String {
        switch service {
        case .slack: return "Slack"
        case .chatwork: return "ChatWork"
        case .googleChat: return "Google Chat"
        }
    }
    
    var isMe: Bool {
        // Mock logic: Assume we are not the sender for now
        return false
    }
}

struct SecureImage: View {
    let url: URL
    let token: String
    
    @State private var image: Image?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                if isLoading {
                    ProgressView()
                        .task {
                            await loadImage()
                        }
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func loadImage() async {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("SecureImage: Status \(httpResponse.statusCode) for \(url.lastPathComponent)")
            }
            
            if let nsImage = NSImage(data: data) {
                self.image = Image(nsImage: nsImage)
            } else {
                print("SecureImage: Failed to decode image data. Data length: \(data.count)")
                if let errorText = String(data: data, encoding: .utf8) {
                    print("SecureImage: Response body: \(errorText)")
                }
            }
        } catch {
            print("Failed to load secure image: \(error)")
        }
        isLoading = false
    }
}
