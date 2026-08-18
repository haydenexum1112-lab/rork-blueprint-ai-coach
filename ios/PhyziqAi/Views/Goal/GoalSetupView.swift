import PhotosUI
import SwiftUI

/// Pick 1–3 goal-physique reference photos with optional captions.
struct GoalSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var drafts: [GoalDraft] = []
    @State private var isLoading: Bool = false

    private struct GoalDraft: Identifiable {
        let id = UUID()
        let data: Data
        let image: UIImage
        var caption: String = ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Upload 1–3 photos of the physique you're working toward. Physique athletes, fitness models — whatever inspires you.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(3)

                        if drafts.isEmpty {
                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 3, matching: .images) {
                                VStack(spacing: 14) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundStyle(Theme.accent)
                                    Text("Add goal photos")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Up to 3 images")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Theme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .strokeBorder(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                                        )
                                )
                            }
                        } else {
                            ForEach($drafts) { $draft in
                                VStack(alignment: .leading, spacing: 10) {
                                    Theme.surfaceHi
                                        .frame(height: 300)
                                        .overlay {
                                            Image(uiImage: draft.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .allowsHitTesting(false)
                                        }
                                        .clipShape(.rect(cornerRadius: 18))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                Haptics.impact(.light)
                                                drafts.removeAll { $0.id == draft.id }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(Circle().fill(.black.opacity(0.55)))
                                            }
                                            .padding(10)
                                        }

                                    TextField(
                                        "",
                                        text: $draft.caption,
                                        prompt: Text("What do you like about this physique?").foregroundStyle(Theme.textSecondary),
                                        axis: .vertical
                                    )
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textPrimary)
                                    .padding(14)
                                    .blueprintCard()
                                }
                            }

                            if drafts.count < 3 {
                                PhotosPicker(selection: $pickerItems, maxSelectionCount: 3 - drafts.count, matching: .images) {
                                    Label("Add another photo", systemImage: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                                        )
                                }
                            }
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                SwiftUI.ProgressView()
                                    .tint(Theme.accent)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Your Goal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save goal") {
                    Haptics.success()
                    saveGoal()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(drafts.isEmpty)
                .opacity(drafts.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.bg.opacity(0.95))
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                loadPicked(newItems)
            }
            .onAppear {
                loadExisting()
            }
        }
        
    }

    private func loadPicked(_ items: [PhotosPickerItem]) {
        isLoading = true
        Task {
            for item in items {
                guard drafts.count < 3 else { break }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let resized = ImageResizer.resize(data, maxBytes: 900_000),
                   let image = UIImage(data: resized) {
                    drafts.append(GoalDraft(data: resized, image: image))
                }
            }
            pickerItems = []
            isLoading = false
        }
    }

    private func loadExisting() {
        guard drafts.isEmpty, let target = appState.target else { return }
        for reference in target.images {
            if let data = ImageStore.loadData(reference.fileName), let image = UIImage(data: data) {
                drafts.append(GoalDraft(data: data, image: image, caption: reference.caption))
            }
        }
    }

    private func saveGoal() {
        // Remove previous goal images before saving replacements.
        if let old = appState.target {
            for image in old.images {
                ImageStore.delete(image.fileName)
            }
        }
        var saved: [TargetImage] = []
        for draft in drafts {
            if let fileName = ImageStore.save(draft.data) {
                saved.append(TargetImage(fileName: fileName, caption: draft.caption))
            }
        }
        guard !saved.isEmpty else { return }
        appState.saveTarget(TargetReference(images: saved))
        dismiss()
    }
}
