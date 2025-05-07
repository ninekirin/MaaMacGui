//
//  CopilotListConfiguration.swift
//  MAA
//
//  Created by ninekirin on 2025/5/6.
//

import Foundation

struct CopilotItemConfiguration: Codable {
    var enabled: Bool = true
    var filename: String
    var name: String
    var is_raid: Bool = false
}

struct CopilotListConfiguration: Codable {
    var enabled: Bool = true 
    var items: [CopilotItemConfiguration] = []
    var formation: Bool = false
    var add_trust: Bool = false
    var use_sanity_potion: Bool = false
    
    var params: String? {
        try? jsonString()
    }
}

// Extension to allow encoding to JSON string
extension CopilotListConfiguration {
    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
