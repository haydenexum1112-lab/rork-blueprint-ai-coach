import PhotosUI
import SwiftUI

/// Guided 3-pose camera capture (front / side / back) with a library fallback.
struct CameraCaptureView: View {
    let onComplete: ([Data]) -> Void
    let onBack: () -> Void

    @State private var camera = CameraService()
    @State private var captured: [Data] = []
    @State private var poseIndex: Int = 0
    @State private var isCapturing: Bool = false
    @State private var flashOpacity: Double = 0
    @State private var libraryItems: [PhotosPickerItem] = []
    @State private var isLoadingLibrary: Bool = false

    private var currentPose: ScanPose {
        ScanPose.allCases[min(poseIndex, 2)]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .running:
                cameraLayer
            case .denied:
                CameraUnavailableView(
                    icon: "lock.shield.fill",
                    title: "Camera access needed",
                    message: "Enable camera access in Settings to scan your physique, or pick photos from your library below.",
                    showsSettingsLink: true,
                    libraryItems: $libraryItems,
                    onBack: onBack
                )
            case .noCamera:
                CameraUnavailableView(
                    icon: "camera.on.rectangle",
                    title: "No camera found",
                    message: "We couldn't find a camera on this device. Pick 3 photos (front, side, back) from your library instead.",
                    showsSettingsLink: false,
                    libraryItems: $libraryItems,
                    onBack: onBack
                )
            case .idle:
                SwiftUI.ProgressView()
                    .tint(Theme.accent)
            }

            Color.black
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: libraryItems) { _, items in
            guard items.count == 3 else { return }
            loadFromLibrary(items)
        }
        .overlay {
            if isLoadingLibrary {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    SwiftUI.ProgressView("Loading photos…")
                        .tint(Theme.accent)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Pose silhouette guide
            VStack {
                Spacer()
                Image(systemName: silhouetteSymbol)
                    .font(.system(size: 320, weight: .ultraLight))
                    .foregroundStyle(Theme.accent.opacity(0.28))
                    .frame(maxHeight: 420)
                Spacer()
                Spacer()
            }
            .allowsHitTesting(false)

            VStack {
                header
                Spacer()
                controls
            }
        }
    }

    private var silhouetteSymbol: String {
        switch currentPose {
        case .front: return "figure.stand"
        case .side: return "figure.walk"
        case .back: return "figure.stand"
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.impact(.light)
                    if poseIndex > 0 {
                        captured.removeLast()
                        poseIndex -= 1
                    } else {
                        onBack()
                    }
                } label: {
                    Image(systemName: poseIndex > 0 ? "arrow.uturn.backward" : "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0 ..< 3, id: \.self) { index in
                        Capsule()
                            .fill(index <= poseIndex ? Theme.accent : Color.black.opacity(0.25))
                            .frame(width: index == poseIndex ? 22 : 10, height: 5)
                    }
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    camera.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 4) {
                Text(currentPose.display.uppercased())
                    .font(.system(size: 22, weight: .black))
                    .tracking(3)
                    .foregroundStyle(.white)
                Text(currentPose.guidance)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.45)))
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        VStack(spacing: 18) {
            Button {
                capture()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.black, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(isCapturing ? Theme.accent : Color.black)
                        .frame(width: 62, height: 62)
                }
            }
            .disabled(isCapturing)

            PhotosPicker(selection: $libraryItems, maxSelectionCount: 3, matching: .images) {
                Text("Choose 3 from library instead")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Capsule().fill(.black.opacity(0.45)))
            }
        }
        .padding(.bottom, 28)
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        Haptics.impact(.heavy)
        withAnimation(.easeOut(duration: 0.12)) { flashOpacity = 0.7 }
        Task {
            let data = await camera.capturePhoto()
            withAnimation(.easeIn(duration: 0.2)) { flashOpacity = 0 }
            if let data {
                captured.append(data)
                if captured.count >= 3 {
                    camera.stop()
                    onComplete(captured)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        poseIndex += 1
                    }
                }
            }
            isCapturing = false
        }
    }

    private func loadFromLibrary(_ items: [PhotosPickerItem]) {
        isLoadingLibrary = true
        Task {
            var loaded: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(data)
                }
            }
            isLoadingLibrary = false
            libraryItems = []
            if loaded.count == 3 {
                camera.stop()
                onComplete(loaded)
            }
        }
    }
}

private struct CameraUnavailableView: View {
    let icon: String
    let title: String
    let message: String
    let showsSettingsLink: Bool
    @Binding var libraryItems: [PhotosPickerItem]
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.displayFont(24))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

            if showsSettingsLink {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            PhotosPicker(selection: $libraryItems, maxSelectionCount: 3, matching: .images) {
                Text("Pick 3 photos from library")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Theme.bg)
    }
}
