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
                            ForEach(viewModel.filteredChannels) { channel in
                                Button(action: {
                                    viewModel.selectedChannel = channel
                                }) {
                                    Text("# \(channel.name)")
                                        .foregroundColor(.white.opacity(viewModel.selectedChannel?.id == channel.id ? 1.0 : 0.8))
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            viewModel.selectedChannel?.id == channel.id
                                            ? Color.white.opacity(0.3)
                                            : Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
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
    
    var backgroundColor: Color {
        switch viewModel.selectedService {
        case .slack: return Color(red: 0.28, green: 0.65, blue: 0.60).opacity(0.9)
        case .chatwork: return Color(red: 0.22, green: 0.24, blue: 0.26).opacity(0.9)
        case .googleChat: return Color(red: 0.93, green: 0.45, blue: 0.25).opacity(0.9)
        case .none: return Color.gray
        }
    }
    
    func serviceName(for service: MessageService) -> String {
        switch service {
        case .slack: return "Slack Channels"
        case .chatwork: return "ChatWork Rooms"
        case .googleChat: return "Google Spaces"
        }
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
                Image(systemName: "photo")
                Image(systemName: "paperclip")
                TextField("Message...", text: .constant(""))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
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
                
                Text(message.body)
                    .padding(12)
                    .background(isMe ? Color.blue.opacity(0.1) : Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 1)
                
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
    
    var isMe: Bool {
        // Mock logic: Assume we are not the sender for now
        return false
    }
}
