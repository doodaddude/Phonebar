import Foundation

/// Represents a user persona / login session for visiting websites.
public struct AccountProfile: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var isAnonymous: Bool
    public var avatarEmoji: String
    public var note: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString,
                name: String,
                isAnonymous: Bool = false,
                avatarEmoji: String = "👤",
                note: String = "",
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.isAnonymous = isAnonymous
        self.avatarEmoji = avatarEmoji
        self.note = note
        self.createdAt = createdAt
    }

    public static let anonymous = AccountProfile(
        id: "anonymous",
        name: "Anonymous (Incognito)",
        isAnonymous: true,
        avatarEmoji: "🕶️",
        note: "Ephemeral session: no cookies or tokens stored on disk."
    )

    public static let defaultProfile = AccountProfile(
        id: "default",
        name: "Computer Default",
        isAnonymous: false,
        avatarEmoji: "👤",
        note: "Uses standard persistent local computer logins."
    )

    public static let defaultProfiles: [AccountProfile] = [
        defaultProfile,
        anonymous,
        AccountProfile(id: "work-profile", name: "Work Persona", avatarEmoji: "💼", note: "Isolated work credentials & accounts"),
        AccountProfile(id: "personal-profile", name: "Personal Persona", avatarEmoji: "🏠", note: "Personal browsing session"),
        AccountProfile(id: "alt-profile", name: "Alt Account", avatarEmoji: "🎭", note: "Secondary / stealth account")
    ]
}
