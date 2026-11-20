# Gloop (prototype)

Gloop is a SwiftUI iPhone app (iOS 17+) where friends and family hold the key
to each other's distracting apps. This first version runs on mock data, so the whole
flow can be tried in the Simulator.

## Run it

1. Install Xcode from the Mac App Store.
2. Double-click `Gloop.swiftpm` (or File → Open in Xcode).
3. Pick an iPhone simulator and press Run.

## What to try

- **Today**: the time blob is a little jelly creature. It wobbles, blinks,
  shrinks as you use time, and changes from slime green to teal to deep ocean
  blue (and gets sleepy) as you run low. Tap it to make it jiggle. Tap a
  limited app to get the block screen and ask for time; the camera button adds
  a photo or video. A yes pops the lock open with confetti and a note from your
  friend. "From your crew" shows friends' nudges: tap the heart, or tap a note
  to reply. The **Limited apps** button opens the full list; Edit there opens
  every app grouped into categories (with search) to pick apps and set limits.
  A friend who's over a limit shows up on Today with a **Slime out** button.
  The gear opens Settings, where you choose how answers count once two or more
  people hold your key.
- **Requests**: give a friend time, or tap the goo splat in the card's corner to
  **slime them out** (that's how you say no). A "Photo"/"Video" chip means they
  sent something; tap it to view, optionally with a note and a photo or video. Another request arrives a
  few seconds later. When a friend turns *you* down, you get slimed instead.
- **Crew**: tap + to invite someone (Buddy vs Family, who holds the key, and the
  consent screen). Tap a person to open your thread and type them a nudge; they
  "type" back a few seconds later. Double-tap a bubble to heart it. The ••• menu
  ends the link.
- **Board**: switch between Streak and Cutting back and watch the ranking reorder.

Keyholders answer at random (about 3 in 4 say yes). To force an answer for a
demo, add `-alwaysDeny` or `-alwaysApprove` as a launch argument
(Xcode: Product → Scheme → Edit Scheme → Run → Arguments).

### Accounts

Logged out, Gloop shows a welcome screen. **Create account** plays the three
intro slides and then offers **Continue with Apple**, **Continue with Google**,
or name, email and password; **I already have an account** goes straight to log
in (no slides), with the same Apple and Google buttons and **Forgot password?**.
You stay logged in between launches. Settings shows your account (and whether
you signed in with Google or Apple), lets you edit your name, change your
password (email accounts only), log out or delete the account, and has your
invite code and join link.

**With the server** (Supabase, set up in `supabase/SETUP.md`), accounts live
online: email confirmation and password reset use 6-digit codes emailed to you,
and a deleted account is deleted on the server. `Services/AuthService.swift`
does all of it; `Services/SupabaseConfig.swift` holds the project URL and key.

**Without the server** (both values in `SupabaseConfig` empty), Gloop falls
back to accounts stored on this phone only, so it still runs in the Simulator.
The password is salted and hashed (SHA-256) and only the hash is kept, in the
Keychain. Apple, Google and Forgot password say they need the server.

Join links use the placeholder `https://gloop.example/join/<code>` (a reserved
address that never belongs to anyone; note that gloop.app is a real, unrelated
site). Change `Account.joinBase` once Gloop has its own domain.

For testing without the server, a sample account: name `Alex Kim`, email
`alex@example.com`, password `jellybean42`. Launch with `-resetAccount` to start
over as a new user.

## Design rules

- Alien jelly theme. Slime-green to deep-ocean palette (`Theme.lime` … `Theme.abyss`).
  Text on the light greens uses `Theme.onColor` (the deepest blue); text on the
  blues is white. Each person has one palette color.
- Jelly touches, kept light: avatars are blob shapes (`BlobShape`), buttons squish
  when pressed (`PressableStyle`), two faint blobs drift behind every screen
  (`AmbientGoo`), the selected tab sits on a blob, and confetti is goo drops.
  Only the time blob and onboarding critters have eyes (`JellyEyes`).
- Small idle motions, all off with Reduce Motion: avatars breathe (`JellyBreath`),
  the time creature does a little squish every few seconds, faint bubbles rise
  around it (only there), the tab blob squashes and stretches when it moves,
  new cards and chat bubbles land with a squish (`.jellyPop`), hearts pop goo
  droplets, and the slime splat's drips slowly stretch.
- Rounded system font everywhere. No emoji are built into the app; icons are
  SF Symbols. People can still type emoji in their own messages.
- Confetti (`ConfettiBurst`) only for real wins: an unlock or saying yes.
- Three springs (`Motion.snappy / smooth / bouncy`) used everywhere.
- Every screen enters with a stagger (`.appear(index)`); Reduce Motion is respected.

The simulator's photo library is empty apart from Apple's samples. To test a
video attachment, add one with `xcrun simctl addmedia booted <file.mp4>`.

The app icon lives in `Assets.xcassets/AppIcon.appiconset` (1024×1024).

## Layout

- `Models/`: data types and `AppModel` (mock state and simulated replies)
- `Motion/`: theme, springs, the lock glyph, rings, shared buttons
- `Views/`: one file per screen
- `Services/ScreenTimeService.swift`: the start of the real Screen Time
  integration and the steps still needed for it
- `Services/AuthService.swift`, `SupabaseConfig.swift`, `AccountStore.swift`: sign-in
- `supabase/`: the database setup script and server setup steps
