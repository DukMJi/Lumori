import Foundation
import FirebaseFirestore

struct LumoriUser: Codable, Identifiable {

    var id: String

    var createdAt: Date

    var connectionID: String?

    var displayName: String?
}
