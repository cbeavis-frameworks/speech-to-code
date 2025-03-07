import Foundation

/// Represents events from the OpenAI Realtime API
struct RealtimeEvent: Codable {
    let id: String?
    let type: String
    let data: RealtimeEventData?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case data
    }
}

/// Data contained within a realtime event
struct RealtimeEventData: Codable {
    let content: [RealtimeContent]?
    let status: String?
    let termination_reason: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case status
        case termination_reason
    }
}

/// Content types that can be received from the Realtime API
struct RealtimeContent: Codable {
    let type: String
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}
