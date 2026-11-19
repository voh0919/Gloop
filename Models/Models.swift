import Foundation

struct Person: Identifiable, Hashable {
    let id: UUID
    var name: String
    var isMinor: Bool
    /// Which palette color this person shows up in.
    var colorIndex: Int

    init(_ name: String, minor: Bool = false, color: Int = .random(in: 0..<5)) {
        self.id = UUID()
        self.name = name
        self.isMinor = minor
        self.colorIndex = color
    }

    var firstName: String { String(name.split(separator: " ").first ?? Substring(name)) }

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

/// Buddy mode uses the "individual" Screen Time permission; Family mode uses
/// Apple Family Sharing ("child" permission) and only the parent can end it.
enum LinkMode: String, CaseIterable, Identifiable {
    case buddy, family
    var id: Self { self }

    var title: String { self == .buddy ? "Buddy" : "Family" }

    var detail: String {
        switch self {
        case .buddy: "Friends, siblings, roommates. Casual and fun. Either of you can leave — it takes 24 hours."
        case .family: "A parent and their child. Only the parent can remove it."
        }
    }

    var symbol: String { self == .buddy ? "person.2" : "house" }
}

enum KeyDirection: String, CaseIterable, Identifiable {
    case holdTheirs, holdMine, both
    var id: Self { self }

    var title: String {
        switch self {
        case .holdTheirs: "I hold their key"
        case .holdMine: "They hold mine"
        case .both: "We hold each other's"
        }
    }

    var symbol: String {
        switch self {
        case .holdTheirs: "arrow.right"
        case .holdMine: "arrow.left"
        case .both: "arrow.left.arrow.right"
        }
    }
}

/// The core building block: a one-way link from a keyholder to a member.
/// Two-way relationships are simply two links.
struct LockLink: Identifiable, Hashable {
    let id = UUID()
    let holder: Person.ID
    let member: Person.ID
    var mode: LinkMode
    var isPending = false
    var leavingAt: Date? = nil
}

struct LimitedApp: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var symbol: String
    var dailyMinutes: Int
    var usedMinutes: Int
    var unlockedUntil: Date? = nil

    var progress: Double { min(1, Double(usedMinutes) / Double(max(dailyMinutes, 1))) }
    var isOver: Bool { usedMinutes >= dailyMinutes }
    func isUnlocked(at date: Date = .now) -> Bool { (unlockedUntil ?? .distantPast) > date }
}

enum RequestState: Equatable {
    case pending
    case approved(Int)
    case denied
}

struct UnlockRequest: Identifiable, Equatable {
    let id = UUID()
    let from: Person.ID
    let appName: String
    let minutes: Int
    let reason: String
    let date: Date
    /// A photo or video the friend sent with their request, as proof or context.
    var proof: Attachment? = nil
    var state: RequestState = .pending
    /// What the keyholder said when they answered.
    var note: String = ""
    /// A photo or video the keyholder sent with their answer.
    var answerMedia: Attachment? = nil
}

/// A group of apps, like Screen Time's "Social" or "Games".
struct AppCategory: Identifiable {
    let name: String
    let symbol: String
    let apps: [(name: String, symbol: String)]
    var id: String { name }
}

/// A nudge: a short message typed by one person to another.
struct Message: Identifiable, Equatable {
    let id = UUID()
    let from: Person.ID
    let to: Person.ID
    let text: String
    let date: Date
    var liked = false
    /// A photo or video sent along with the message.
    var media: Attachment? = nil
    /// Set when this message is a request for time or an answer to one,
    /// so chats show the whole back-and-forth.
    var event: ChatEvent? = nil

    /// One line for previews like the Crew list.
    var preview: String {
        switch event {
        case .request(let app, let minutes):
            return text.isEmpty ? "Asked for \(minutes) min on \(app)" : text
        case .gave(let minutes, _):
            return text.isEmpty ? "Gave \(minutes) min" : text
        case .slimed(let app):
            return text.isEmpty ? "Slimed out of \(app)" : text
        case nil:
            return text.isEmpty ? (media == nil ? "" : "Sent a photo") : text
        }
    }
}

/// A request for more time, or the answer to one, shown inside a chat.
enum ChatEvent: Equatable {
    case request(app: String, minutes: Int)
    case gave(minutes: Int, app: String)
    case slimed(app: String)
}

struct Stats: Hashable {
    var streak: Int
    /// Percent less screen time than the person's own average.
    var improvement: Int
    var minutesToday: Int
    var limitToday: Int
    /// The app they're over their limit on right now, if any.
    var overApp: String? = nil
    var overMinutes: Int = 0
}

/// Someone got slimed out of an app. Drives the full-screen slime animation.
struct SlimeEvent: Identifiable, Equatable {
    let id = UUID()
    let person: Person
    let app: String
    /// true: I slimed them. false: they slimed me.
    let byMe: Bool
}

/// What happens when several people hold one person's key.
enum ApprovalRule: String, CaseIterable, Identifiable {
    case firstToAnswer, anyoneCanDeny
    var id: Self { self }

    var title: String {
        switch self {
        case .firstToAnswer: "First to answer"
        case .anyoneCanDeny: "Anyone can slime you out"
        }
    }

    var detail: String {
        switch self {
        case .firstToAnswer: "Whoever answers first decides."
        case .anyoneCanDeny: "You only get time if nobody slimes you out."
        }
    }
}

enum Relation {
    case mutual, holdsMine, iHold

    var label: String {
        switch self {
        case .mutual: "Each other's keys"
        case .holdsMine: "Holds your key"
        case .iHold: "You hold their key"
        }
    }

    var symbol: String {
        switch self {
        case .mutual: "arrow.left.arrow.right"
        case .holdsMine: "arrow.left"
        case .iHold: "arrow.right"
        }
    }
}

struct Relationship: Identifiable, Hashable {
    let person: Person
    let relation: Relation
    let mode: LinkMode
    let isPending: Bool
    let leavingAt: Date?
    var id: Person.ID { person.id }

    var iHoldTheirKey: Bool { relation != .holdsMine }
}

struct BoardEntry: Identifiable, Hashable {
    let person: Person
    let stats: Stats
    let isMe: Bool
    var id: Person.ID { person.id }
}
