import Foundation

struct Channel: Identifiable, Hashable {
    let id: String
    let name: String
    let service: MessageService
    let isDM: Bool
}
