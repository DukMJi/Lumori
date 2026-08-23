import Foundation


struct Connection: Codable, Identifiable {

    var id: String

    var userA: String

    var userB: String?

    var createdAt: Date
}
