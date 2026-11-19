import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// A photo or short video attached to a request or an answer
/// ("here's my finished homework", "show me your desk first").
struct Attachment: Identifiable, Equatable {
    enum Kind { case photo, video }
    let id = UUID()
    let kind: Kind
    let thumbnail: UIImage
    /// Only for videos: where the movie file lives.
    let videoURL: URL?
}

// MARK: - The camera button

/// A round camera button. Tapping it offers the camera (photo or video) or the
/// photo library. Once something is attached it turns into a thumbnail with a
/// remove badge; tapping the thumbnail opens it full screen.
struct AttachButton: View {
    @Binding var attachment: Attachment?
    var size: CGFloat = 46

    @State private var choosing = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var viewing: Attachment?
    @State private var loading = false

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ZStack {
            if let attachment {
                Button { viewing = attachment } label: {
                    AttachmentThumb(attachment: attachment, size: size)
                }
                .buttonStyle(.pressable)
                .overlay(alignment: .topTrailing) {
                    Button { withAnimation(Motion.bouncy) { self.attachment = nil } } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Theme.onColor, in: Circle())
                    }
                    .offset(x: 6, y: -6)
                    .accessibilityLabel("Remove attachment")
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Button {
                    if cameraAvailable { choosing = true } else { showLibrary = true }
                } label: {
                    ZStack {
                        if loading {
                            ProgressView().tint(Theme.onColor)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.36, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Theme.onColor)
                    .frame(width: size, height: size)
                    .background(Theme.lime.opacity(0.6), in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Add a photo or video")
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(Motion.bouncy, value: attachment)
        .confirmationDialog("Add a photo or video", isPresented: $choosing) {
            Button("Take photo or video") { showCamera = true }
            Button("Choose from library") { showLibrary = true }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { result in
                withAnimation(Motion.bouncy) { attachment = result }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem,
                      matching: .any(of: [.images, .videos]))
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            loading = true
            Task {
                let result = await Attachment.load(from: item)
                loading = false
                libraryItem = nil
                withAnimation(Motion.bouncy) { attachment = result }
            }
        }
        .fullScreenCover(item: $viewing) { MediaViewer(attachment: $0) }
    }
}

/// A rounded thumbnail, with a play badge for videos.
struct AttachmentThumb: View {
    let attachment: Attachment
    var size: CGFloat = 46

    var body: some View {
        Image(uiImage: attachment.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                if attachment.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(Theme.onColor.opacity(0.1), lineWidth: 1))
    }
}

/// Full-screen look at a photo, or a playable video.
struct MediaViewer: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Group {
                if attachment.kind == .video, let url = attachment.videoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                } else {
                    Image(uiImage: attachment.thumbnail)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.6), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            }
            .padding(20)
        }
    }
}

// MARK: - Loading media

extension Attachment {
    /// Turns a photo-library pick into an attachment.
    static func load(from item: PhotosPickerItem) async -> Attachment? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try? await item.loadTransferable(type: Movie.self) else { return nil }
            return await video(at: movie.url)
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return Attachment(kind: .photo, thumbnail: image, videoURL: nil)
    }

    /// Makes a still frame for a video's thumbnail.
    static func video(at url: URL) async -> Attachment? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let frame = try? await generator.image(at: .zero).image else { return nil }
        return Attachment(kind: .video, thumbnail: UIImage(cgImage: frame), videoURL: url)
    }
}

/// Lets PhotosPicker hand over a video as a file we can keep.
struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}

// MARK: - The camera

/// The system camera, set up to take either a photo or a video (up to 30 seconds).
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (Attachment) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoMaximumDuration = 30
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                Task { @MainActor in
                    if let a = await Attachment.video(at: url) { parent.onPick(a) }
                    parent.dismiss()
                }
            } else if let image = info[.originalImage] as? UIImage {
                parent.onPick(Attachment(kind: .photo, thumbnail: image, videoURL: nil))
                parent.dismiss()
            } else {
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
