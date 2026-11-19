import SwiftUI

/// Sample photos for the prototype's mock requests (the simulator has no real
/// friends to send pictures). Drawn on the fly as simple "screenshots".
@MainActor
enum MockMedia {
    static func screenshot(title: String, subtitle: String, symbol: String, progress: Double) -> Attachment? {
        let card = VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.ocean, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(subtitle).font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Theme.deep, Theme.abyss], startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "play.fill").font(.system(size: 30)).foregroundStyle(.white.opacity(0.85)))
                .frame(height: 120)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.1))
                    Capsule().fill(Theme.sea).frame(width: g.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .frame(width: 360, height: 280, alignment: .top)
        .background(Color.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        return Attachment(kind: .photo, thumbnail: image, videoURL: nil)
    }
}
