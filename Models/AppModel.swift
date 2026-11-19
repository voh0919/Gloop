import Foundation
import Observation

/// App state. For now everything is mock data and simulated replies;
/// later this talks to a server (links, requests, nudges) and to
/// `ScreenTimeService` (blocking apps on the phone).
@MainActor
@Observable
final class AppModel {
    /// The signed-in account, or nil when logged out.
    var account: Account?
    var isLoggedIn: Bool { account != nil }

    var me: Person
    var people: [Person]
    var links: [LockLink]
    var apps: [LimitedApp]
    var requests: [UnlockRequest]
    var stats: [Person.ID: Stats]
    var approvalRule: ApprovalRule = .firstToAnswer
    /// Every typed nudge, both directions.
    var messages: [Message]
    /// People currently "typing" a reply to me.
    var typing: Set<Person.ID> = []
    /// People I've slimed out of the app they were overusing.
    var slimed: Set<Person.ID> = []
    /// The slime animation currently playing, if any.
    var slimeEvent: SlimeEvent? = nil

    /// The app whose block screen is showing.
    var blockingApp: LimitedApp? = nil
    var toast: String? = nil

    private var toastTask: Task<Void, Never>? = nil
    private var demoRequestsLeft = 2

    init() {
        // Demo switch: launch with -resetAccount to start over as a brand-new user.
        if ProcessInfo.processInfo.arguments.contains("-resetAccount") {
            AccountStore.deleteAccount()
        }
        let signedIn = AccountStore.isLoggedIn ? AccountStore.account : nil
        account = signedIn
        let me = Person(signedIn?.name ?? "You", color: 2)
        let sam = Person("Sam Rivera", color: 0)
        let maya = Person("Maya Chen", color: 3)
        let nora = Person("Nora Park", color: 1)
        let leo = Person("Leo Kim", minor: true, color: 4)

        self.me = me
        people = [sam, maya, nora, leo]

        links = [
            LockLink(holder: me.id, member: sam.id, mode: .buddy),
            LockLink(holder: sam.id, member: me.id, mode: .buddy),
            LockLink(holder: maya.id, member: me.id, mode: .buddy),
            LockLink(holder: me.id, member: nora.id, mode: .buddy),
            LockLink(holder: me.id, member: leo.id, mode: .family),
        ]

        apps = [
            LimitedApp(name: "Instagram", symbol: "camera", dailyMinutes: 30, usedMinutes: 30),
            LimitedApp(name: "TikTok", symbol: "music.note", dailyMinutes: 20, usedMinutes: 12),
            LimitedApp(name: "YouTube", symbol: "play.rectangle", dailyMinutes: 45, usedMinutes: 19),
            LimitedApp(name: "Roblox", symbol: "gamecontroller", dailyMinutes: 30, usedMinutes: 4),
        ]

        let now = Date.now
        requests = [
            UnlockRequest(from: leo.id, appName: "YouTube", minutes: 15,
                          reason: "Finishing a tutorial for school", date: now.addingTimeInterval(-4 * 60),
                          proof: MockMedia.screenshot(title: "Python for Beginners",
                                                      subtitle: "Lesson 4 of 6 · 9 min left",
                                                      symbol: "play.rectangle.fill", progress: 0.62)),
            UnlockRequest(from: nora.id, appName: "Instagram", minutes: 5,
                          reason: "", date: now.addingTimeInterval(-11 * 60),
                          proof: MockMedia.screenshot(title: "Group project",
                                                      subtitle: "Maya: can someone post the poster?",
                                                      symbol: "bubble.left.and.bubble.right.fill", progress: 0.4)),
            UnlockRequest(from: sam.id, appName: "TikTok", minutes: 15, reason: "",
                          date: now.addingTimeInterval(-3 * 3600), state: .denied),
        ]

        messages = [
            Message(from: me.id, to: nora.id, text: "12 days?? teach me your ways", date: now.addingTimeInterval(-26 * 3600)),
            Message(from: nora.id, to: me.id, text: "phone in the other room. works every time", date: now.addingTimeInterval(-25 * 3600)),
            Message(from: me.id, to: sam.id, text: "you better not be scrolling rn", date: now.addingTimeInterval(-70 * 60)),
            Message(from: maya.id, to: me.id, text: "proud of you for staying off tiktok yesterday!!", date: now.addingTimeInterval(-2 * 3600)),
            Message(from: sam.id, to: me.id, text: "gym at 6? phones stay in the locker", date: now.addingTimeInterval(-20 * 60)),
        ]

        stats = [
            me.id: Stats(streak: 6, improvement: 22, minutesToday: 65, limitToday: 125),
            sam.id: Stats(streak: 9, improvement: 14, minutesToday: 104, limitToday: 90,
                          overApp: "TikTok", overMinutes: 14),
            maya.id: Stats(streak: 3, improvement: 31, minutesToday: 70, limitToday: 120),
            nora.id: Stats(streak: 12, improvement: 8, minutesToday: 25, limitToday: 60),
            leo.id: Stats(streak: 4, improvement: 18, minutesToday: 52, limitToday: 90),
        ]

        // Every request (and answer) also lives in that friend's chat.
        for r in requests {
            messages.append(Message(from: r.from, to: self.me.id, text: r.reason, date: r.date,
                                    media: r.proof, event: .request(app: r.appName, minutes: r.minutes)))
            if r.state == .denied {
                messages.append(Message(from: self.me.id, to: r.from, text: "", date: r.date.addingTimeInterval(90),
                                        event: .slimed(app: r.appName)))
            }
        }
    }

    // MARK: Account

    func createAccount(name: String, email: String, password: String) throws {
        let a = try AccountStore.createAccount(name: name, email: email, password: password)
        me.name = a.name
        account = a
    }

    func logIn(email: String, password: String) throws {
        let a = try AccountStore.logIn(email: email, password: password)
        me.name = a.name
        account = a
    }

    func logOut() {
        AccountStore.logOut()
        account = nil
    }

    func updateName(_ name: String) throws {
        let a = try AccountStore.updateName(name)
        me.name = a.name
        account = a
        showToast("Name updated")
    }

    func changePassword(current: String, new: String) throws {
        try AccountStore.changePassword(current: current, new: new)
        showToast("Password changed")
    }

    func deleteAccount() {
        AccountStore.deleteAccount()
        account = nil
    }

    // MARK: Lookups

    func person(_ id: Person.ID) -> Person? {
        id == me.id ? me : people.first { $0.id == id }
    }

    var myKeyholders: [Person] {
        links.filter { $0.member == me.id && !$0.isPending }.compactMap { person($0.holder) }
    }

    var pendingIncoming: [UnlockRequest] { requests.filter { $0.state == .pending } }
    var answeredRequests: [UnlockRequest] { requests.filter { $0.state != .pending } }

    var totalUsed: Int { apps.reduce(0) { $0 + min($1.usedMinutes, $1.dailyMinutes) } }
    var totalLimit: Int { apps.reduce(0) { $0 + $1.dailyMinutes } }

    var relationships: [Relationship] {
        people.compactMap { p in
            let mine = links.first { $0.holder == p.id && $0.member == me.id }
            let theirs = links.first { $0.holder == me.id && $0.member == p.id }
            let relation: Relation
            switch (mine, theirs) {
            case (.some, .some): relation = .mutual
            case (.some, nil): relation = .holdsMine
            case (nil, .some): relation = .iHold
            case (nil, nil): return nil
            }
            let link = (theirs ?? mine)!
            return Relationship(
                person: p, relation: relation, mode: link.mode,
                isPending: (mine?.isPending ?? false) || (theirs?.isPending ?? false),
                leavingAt: mine?.leavingAt ?? theirs?.leavingAt
            )
        }
    }

    func relationship(with id: Person.ID) -> Relationship? {
        relationships.first { $0.id == id }
    }

    /// The leaderboard shows you plus active relationships. Under-18s only
    /// rank alongside people their own age, or family.
    var board: [BoardEntry] {
        var entries = [BoardEntry(person: me, stats: stats[me.id]!, isMe: true)]
        for r in relationships where !r.isPending {
            guard r.person.isMinor == me.isMinor || r.mode == .family,
                  let s = stats[r.person.id] else { continue }
            entries.append(BoardEntry(person: r.person, stats: s, isMe: false))
        }
        return entries
    }

    // MARK: Requests I answer

    func answer(_ request: UnlockRequest, minutes: Int?, note: String = "", media: Attachment? = nil) {
        guard let i = requests.firstIndex(where: { $0.id == request.id }) else { return }
        requests[i].state = minutes.map { .approved($0) } ?? .denied
        requests[i].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        requests[i].answerMedia = media
        messages.append(Message(from: me.id, to: request.from, text: requests[i].note, date: .now,
                                media: media,
                                event: minutes.map { .gave(minutes: $0, app: request.appName) }
                                    ?? .slimed(app: request.appName)))
        let name = person(request.from)?.firstName ?? "them"
        showToast(minutes.map { "Gave \(name) \($0) min" } ?? "Splat! Slimed \(name) out")
        scheduleDemoRequestIfIdle()
    }

    /// Keeps the prototype lively: once you clear your requests,
    /// someone else asks a few seconds later.
    private func scheduleDemoRequestIfIdle() {
        guard pendingIncoming.isEmpty, demoRequestsLeft > 0 else { return }
        demoRequestsLeft -= 1
        Task {
            try? await Task.sleep(for: .seconds(6))
            let candidates = relationships.filter { $0.iHoldTheirKey && !$0.isPending }
            guard let who = candidates.randomElement() else { return }
            let options: [(String, Int, String)] = [
                ("TikTok", 15, "Just want to finish one video"),
                ("Instagram", 5, "Replying to a message"),
                ("YouTube", 30, ""),
            ]
            let pick = options.randomElement()!
            // Sometimes friends send a screenshot along with their reason.
            let proof = pick.2.isEmpty || Bool.random() ? nil
                : MockMedia.screenshot(title: pick.0, subtitle: pick.2,
                                       symbol: "photo.fill", progress: .random(in: 0.3...0.9))
            requests.insert(UnlockRequest(from: who.id, appName: pick.0, minutes: pick.1,
                                          reason: pick.2, date: .now, proof: proof), at: 0)
            messages.append(Message(from: who.id, to: me.id, text: pick.2, date: .now, media: proof,
                                    event: .request(app: pick.0, minutes: pick.1)))
            showToast("\(who.person.firstName) is asking for time")
        }
    }

    // MARK: Requests I send

    /// Simulates asking my keyholders. Doesn't change any state, so the
    /// block screen can cancel safely.
    func askForTime(minutes: Int, app: String = "", reason: String = "",
                    proof: Attachment? = nil) async -> (approved: Bool, by: Person?, note: String) {
        let askedAt = Date.now
        try? await Task.sleep(for: .seconds(2.8))
        let by = myKeyholders.randomElement()
        // Demo switches: launch with -alwaysDeny or -alwaysApprove to force an answer.
        let args = ProcessInfo.processInfo.arguments
        let approved: Bool
        if args.contains("-alwaysDeny") {
            approved = false
        } else if args.contains("-alwaysApprove") {
            approved = true
        } else {
            approved = Double.random(in: 0...1) < (approvalRule == .firstToAnswer ? 0.75 : 0.6)
        }
        let notes = approved
            ? ["go for it", "ok but just this once", "you earned it", "enjoy, then back to work"]
            : ["finish your essay first", "go touch some grass", "nope. you've got this", "ask me again after dinner"]
        let note = notes.randomElement()!
        if let by, !app.isEmpty {
            messages.append(Message(from: me.id, to: by.id, text: reason.trimmingCharacters(in: .whitespaces),
                                    date: askedAt, media: proof, event: .request(app: app, minutes: minutes)))
            messages.append(Message(from: by.id, to: me.id, text: note, date: .now,
                                    event: approved ? .gave(minutes: minutes, app: app) : .slimed(app: app)))
        }
        return (approved, by, note)
    }

    // MARK: Limited apps

    /// The apps on this phone, grouped like Screen Time groups them.
    /// iOS doesn't let apps read the installed-app list directly: on a real iPhone
    /// this comes from Apple's FamilyActivityPicker (see ScreenTimeService),
    /// which shows the same categories with the person's actual apps.
    static let categories: [AppCategory] = [
        AppCategory(name: "Social", symbol: "person.2.fill", apps: [
            ("Instagram", "camera"), ("TikTok", "music.note"), ("Snapchat", "bolt.horizontal"),
            ("X", "text.bubble"), ("Facebook", "person.2"), ("Threads", "at"),
            ("BeReal", "camera.on.rectangle"), ("Discord", "bubble.left.and.bubble.right"),
            ("WhatsApp", "phone.bubble")]),
        AppCategory(name: "Entertainment", symbol: "play.tv.fill", apps: [
            ("YouTube", "play.rectangle"), ("Netflix", "tv"), ("Twitch", "dot.radiowaves.left.and.right"),
            ("Disney+", "sparkles.tv"), ("Spotify", "music.note.list"), ("Hulu", "play.tv")]),
        AppCategory(name: "Games", symbol: "gamecontroller.fill", apps: [
            ("Roblox", "gamecontroller"), ("Minecraft", "cube"), ("Clash Royale", "crown"),
            ("Candy Crush", "circle.hexagongrid"), ("Fortnite", "scope"), ("Among Us", "person.fill.questionmark")]),
        AppCategory(name: "Shopping & Food", symbol: "bag.fill", apps: [
            ("Amazon", "cart"), ("Shein", "bag"), ("Temu", "tag"), ("DoorDash", "takeoutbag.and.cup.and.straw")]),
        AppCategory(name: "Information & Reading", symbol: "book.fill", apps: [
            ("Reddit", "newspaper"), ("Pinterest", "pin"), ("News", "doc.richtext"), ("Kindle", "book")]),
        AppCategory(name: "Productivity & Finance", symbol: "briefcase.fill", apps: [
            ("Gmail", "envelope"), ("Notion", "doc.text"), ("Slack", "number"), ("Venmo", "dollarsign.circle")]),
        AppCategory(name: "Health & Fitness", symbol: "heart.fill", apps: [
            ("Strava", "figure.run"), ("MyFitnessPal", "fork.knife")]),
        AppCategory(name: "Education", symbol: "graduationcap.fill", apps: [
            ("Duolingo", "character.book.closed"), ("Khan Academy", "graduationcap")]),
        AppCategory(name: "Creativity", symbol: "paintbrush.fill", apps: [
            ("CapCut", "scissors"), ("Canva", "paintpalette"), ("GarageBand", "guitars")]),
        AppCategory(name: "Utilities", symbol: "wrench.and.screwdriver.fill", apps: [
            ("Safari", "safari"), ("Maps", "map"), ("Calculator", "plus.forwardslash.minus")]),
    ]

    /// Replaces the limited apps, keeping today's usage for apps that stay on the list.
    func saveApps(_ choices: [(name: String, symbol: String, minutes: Int)]) {
        apps = choices.map { choice in
            if var existing = apps.first(where: { $0.name == choice.name }) {
                existing.dailyMinutes = choice.minutes
                return existing
            }
            return LimitedApp(name: choice.name, symbol: choice.symbol,
                              dailyMinutes: choice.minutes, usedMinutes: 0)
        }
        showToast("Limits saved")
    }

    func grantUnlock(_ app: LimitedApp, minutes: Int) {
        guard let i = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[i].unlockedUntil = .now.addingTimeInterval(Double(minutes * 60))
    }

    // MARK: Relationships

    /// Returns why an invite isn't allowed, or nil if it's fine.
    func inviteBlockedReason(isMinor: Bool, mode: LinkMode) -> String? {
        if isMinor != me.isMinor && mode == .buddy {
            return "Buddy links between adults and under-18s aren't allowed. If you're their parent, use Family."
        }
        if me.isMinor && mode == .family {
            return "Family links are set up by the parent."
        }
        return nil
    }

    func invite(name: String, isMinor: Bool, mode: LinkMode, direction: KeyDirection) {
        let p = Person(name, minor: isMinor)
        people.append(p)
        let dir: KeyDirection = mode == .family ? .holdTheirs : direction
        if dir != .holdMine {
            links.append(LockLink(holder: me.id, member: p.id, mode: mode, isPending: true))
        }
        if dir != .holdTheirs {
            links.append(LockLink(holder: p.id, member: me.id, mode: mode, isPending: true))
        }
        stats[p.id] = Stats(streak: 0, improvement: 0, minutesToday: 0, limitToday: 60)
        showToast("Invite sent to \(p.firstName)")

        // Simulate them accepting.
        Task {
            try? await Task.sleep(for: .seconds(4))
            for i in links.indices where links[i].holder == p.id || links[i].member == p.id {
                links[i].isPending = false
            }
            showToast("\(p.firstName) accepted")
        }
    }

    /// Buddy links end 24 hours after someone chooses to leave.
    func startLeaving(_ id: Person.ID) {
        let at = Date.now.addingTimeInterval(24 * 3600)
        for i in links.indices where involves(links[i], id) && links[i].mode == .buddy {
            links[i].leavingAt = at
        }
    }

    func cancelLeaving(_ id: Person.ID) {
        for i in links.indices where involves(links[i], id) { links[i].leavingAt = nil }
    }

    /// Only possible when I'm the parent in a Family link.
    func removeFamilyLink(_ id: Person.ID) {
        links.removeAll { $0.holder == me.id && $0.member == id && $0.mode == .family }
        showToast("Removed")
    }

    private func involves(_ link: LockLink, _ id: Person.ID) -> Bool {
        (link.holder == me.id && link.member == id) || (link.holder == id && link.member == me.id)
    }

    // MARK: Messages (nudges)

    /// Messages between me and one person, oldest first.
    func thread(with id: Person.ID) -> [Message] {
        messages
            .filter { ($0.from == me.id && $0.to == id) || ($0.from == id && $0.to == me.id) }
            .sorted { $0.date < $1.date }
    }

    /// Nudges friends sent me, newest first.
    var inbox: [Message] {
        messages.filter { $0.to == me.id && $0.event == nil }.sorted { $0.date > $1.date }
    }

    func sendMessage(_ text: String, to person: Person) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(Message(from: me.id, to: person.id, text: text, date: .now))

        // Simulate a friend writing back, so the thread feels alive.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            typing.insert(person.id)
            try? await Task.sleep(for: .seconds(2.2))
            typing.remove(person.id)
            let replies = ["haha ok ok", "you're right, putting it down", "thank youuu",
                           "on it", "fine, fine", "you too!! no excuses"]
            messages.append(Message(from: person.id, to: me.id,
                                    text: replies.randomElement()!, date: .now))
        }
    }

    // MARK: Slime out

    /// Friends whose key I hold who are over a limit right now.
    var crewOverLimit: [(person: Person, stats: Stats)] {
        relationships
            .filter { $0.iHoldTheirKey && !$0.isPending }
            .compactMap { r in
                guard let s = stats[r.id], s.overApp != nil else { return nil }
                return (r.person, s)
            }
    }

    /// Slimes a friend out of an app: locks it again and plays the slime animation.
    /// Used both for friends who are over their limit and in place of saying no to a request.
    func slimeOut(_ person: Person, app: String, fromRequest: Bool = false) {
        slimed.insert(person.id)
        slimeEvent = SlimeEvent(person: person, app: app, byMe: true)
        if !fromRequest {
            messages.append(Message(from: me.id, to: person.id, text: "", date: .now,
                                    event: .slimed(app: app)))
            // Simulate their (grudging) reply.
            Task {
                try? await Task.sleep(for: .seconds(5))
                messages.append(Message(from: person.id, to: me.id,
                                        text: ["ok ok, I'm off", "I'm still finding goo in my phone", "the slime was uncalled for",
                                               "fine. I'll go touch grass. sticky grass.",
                                               "who taught you to throw like that",
                                               "my thumbs are glued together now. you win"].randomElement()!,
                                        date: .now))
            }
        }
    }

    func toggleLike(_ message: Message) {
        guard let i = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[i].liked.toggle()
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        toast = text
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            if !Task.isCancelled { toast = nil }
        }
    }
}
