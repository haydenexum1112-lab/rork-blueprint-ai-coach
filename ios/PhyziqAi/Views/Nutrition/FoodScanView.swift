import PhotosUI
import SwiftUI

/// Cal AI-style food scanner: snap or pick a photo, AI identifies the food and estimates macros,
/// you can edit/remove items before logging.
struct FoodScanView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var pickedImage: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var scanResult: FoodScanResult?
    @State private var editableItems: [ScannedFoodItem] = []
    @State private var editingItemId: UUID?
    @State private var suggestedSlot: MealSlot = .snack
    @State private var mealSlot: MealSlot = .snack
    @State private var isScanning: Bool = false
    @State private var errorMessage: String?
    @State private var errorDiagnostic: String?
    @State private var showCamera: Bool = false

    @State private var isLoadingFromLibrary: Bool = false

    private var liveTotals: (cal: Int, p: Int, c: Int, f: Int) {
        let cal = editableItems.reduce(0) { $0 + $1.calories }
        let p = editableItems.reduce(0) { $0 + $1.proteinGrams }
        let c = editableItems.reduce(0) { $0 + $1.carbsGrams }
        let f = editableItems.reduce(0) { $0 + $1.fatGrams }
        return (cal, p, c, f)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let image = pickedImage {
                        photoPreview(image)
                    } else {
                        photoPicker
                    }

                    if isScanning || isLoadingFromLibrary {
                        scanningView
                    }

                    if !editableItems.isEmpty {
                        resultsView
                    }

                    if let error = errorMessage {
                        errorView(error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .navigationTitle("Scan food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                FoodScanCameraSheet { image in
                    pickedImage = image
                    Task { await scanImage(image) }
                }
            }
            .onChange(of: pickedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isLoadingFromLibrary = true
                    defer { isLoadingFromLibrary = false }
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                        errorMessage = "Couldn't load that photo. Try again or take a new one."
                        return
                    }
                    guard let image = UIImage(data: data) else {
                        errorMessage = "That image couldn't be read. Try a different photo."
                        return
                    }
                    pickedImage = image
                    await scanImage(image)
                }
            }
        }
    }

    // MARK: - Photo picker

    private var photoPicker: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("Snap a photo of your meal")
                    .font(.displayFont(24))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("AI will identify the food and estimate calories and macros. You can edit before logging.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    )
            )

            VStack(spacing: 10) {
                Button {
                    Haptics.impact(.light)
                    showCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
                }

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Photo preview

    private func photoPreview(_ image: UIImage) -> some View {
        VStack(spacing: 12) {
            Color(.secondarySystemBackground)
                .frame(height: 240)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if !isScanning && editableItems.isEmpty {
                        Button {
                            Haptics.impact(.light)
                            pickedImage = nil
                            pickedItem = nil
                            scanResult = nil
                            editableItems = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(10)
                    }
                }

            if !isScanning && editableItems.isEmpty && errorMessage == nil {
                Button {
                    Task { await scanImage(image) }
                } label: {
                    Label("Scan this photo", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
            }
        }
    }

    // MARK: - Scanning state

    private var scanningView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.2)
            Text(isLoadingFromLibrary ? "Loading photo…" : "Identifying your food…")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(isLoadingFromLibrary ? "Preparing your image" : "Estimating portions and macros")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .blueprintCard()
    }

    // MARK: - Results (editable)

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description + live totals
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                    Text("AI DETECTED · TAP TO EDIT")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                }
                if let result = scanResult {
                    Text(result.description)
                        .font(.displayFont(20))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(2)
                }

                let t = liveTotals
                HStack(spacing: 14) {
                    macroTotal(value: "\(t.cal)", label: "kcal", color: Theme.accent)
                    macroTotal(value: "\(t.p)g", label: "Protein", color: Theme.success)
                    macroTotal(value: "\(t.c)g", label: "Carbs", color: Theme.warning)
                    macroTotal(value: "\(t.f)g", label: "Fat", color: Color.purple)
                }
            }
            .padding(16)
            .blueprintCard()

            // Meal slot picker
            mealSlotPicker

            // Items (editable)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(editableItems.count) ITEM\(editableItems.count == 1 ? "" : "S")")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.3)) {
                            editableItems.append(ScannedFoodItem(
                                id: UUID(),
                                name: "Custom item",
                                emoji: "🍽️",
                                calories: 0,
                                proteinGrams: 0,
                                carbsGrams: 0,
                                fatGrams: 0,
                                servings: 1,
                                portion: "1 serving",
                                confidence: "estimate"
                            ))
                            editingItemId = editableItems.last?.id
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                ForEach(editableItems) { item in
                    editableItemRow(item)
                }
            }

            // Log button
            Button {
                logItems()
            } label: {
                Label("Log this meal", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
            }

            Button {
                Haptics.impact(.light)
                pickedImage = nil
                pickedItem = nil
                scanResult = nil
                editableItems = []
                errorMessage = nil
            } label: {
                Text("Scan another photo")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Meal slot picker

    private var mealSlotPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEAL")
                .font(.system(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(MealSlot.allCases) { slot in
                    Button {
                        Haptics.impact(.light)
                        mealSlot = slot
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: slot.icon)
                                .font(.system(size: 14))
                            Text(slot.display)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(mealSlot == slot ? Color.black : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(mealSlot == slot ? Theme.accent : Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(mealSlot == slot ? Color.clear : Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Editable item row

    private func editableItemRow(_ item: ScannedFoodItem) -> some View {
        let isEditing = editingItemId == item.id
        return VStack(spacing: 0) {
            // Collapsed header
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 8) {
                        Text(item.portion)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        confidenceBadge(item.confidence)
                    }
                    HStack(spacing: 10) {
                        Text("\(item.calories) kcal")
                        if item.proteinGrams > 0 { Text("\(item.proteinGrams)g P") }
                        if item.carbsGrams > 0 { Text("\(item.carbsGrams)g C") }
                        if item.fatGrams > 0 { Text("\(item.fatGrams)g F") }
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3)) {
                        editingItemId = isEditing ? nil : item.id
                    }
                } label: {
                    Image(systemName: isEditing ? "chevron.up" : "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.accent.opacity(0.1)))
                }
            }
            .padding(12)

            if isEditing {
                Divider().background(Theme.hairline)
                editControls(for: item)
                    .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }

    private func editControls(for item: ScannedFoodItem) -> some View {
        VStack(spacing: 14) {
            // Name + emoji
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Food name", text: binding(for: item, keyPath: \.name))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("EMOJI")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textSecondary)
                    TextField("🍽️", text: binding(for: item, keyPath: \.emoji))
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 56, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                }
            }

            // Portion
            VStack(alignment: .leading, spacing: 4) {
                Text("PORTION DESCRIPTION")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                TextField("e.g. 1 cup, 2 slices", text: binding(for: item, keyPath: \.portion))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            }

            // Servings stepper
            HStack {
                Text("Servings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Stepper(value: binding(for: item, keyPath: \.servings), in: 0.25 ... 10, step: 0.25) {
                    Text(String(format: "%.2f", item.servings))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
            }

            // Macro steppers grid
            VStack(alignment: .leading, spacing: 8) {
                Text("MACROS")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    macroStepper(label: "kcal", value: binding(for: item, keyPath: \.calories), step: 5, color: Theme.accent)
                    macroStepper(label: "P", value: binding(for: item, keyPath: \.proteinGrams), step: 1, color: Theme.success)
                }
                HStack(spacing: 10) {
                    macroStepper(label: "C", value: binding(for: item, keyPath: \.carbsGrams), step: 1, color: Theme.warning)
                    macroStepper(label: "F", value: binding(for: item, keyPath: \.fatGrams), step: 1, color: Color.purple)
                }
            }

            // Delete
            Button(role: .destructive) {
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.3)) {
                    editableItems.removeAll { $0.id == item.id }
                    if editingItemId == item.id { editingItemId = nil }
                }
            } label: {
                Label("Remove item", systemImage: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
            }
        }
    }

    private func macroStepper(label: String, value: Binding<Int>, step: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Spacer()
            Stepper(value: value, in: 0 ... 9999, step: step) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
    }

    /// Helper to create a binding to a `ScannedFoodItem` field inside `editableItems`.
    private func binding<T>(for item: ScannedFoodItem, keyPath: WritableKeyPath<ScannedFoodItem, T>) -> Binding<T> {
        Binding<T>(
            get: {
                editableItems.first(where: { $0.id == item.id })?[keyPath: keyPath] ?? item[keyPath: keyPath]
            },
            set: { newValue in
                if let idx = editableItems.firstIndex(where: { $0.id == item.id }) {
                    editableItems[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func confidenceBadge(_ confidence: String) -> some View {
        let color: Color = confidence == "confident" ? Theme.success : (confidence == "likely" ? Theme.accent : Theme.warning)
        return Text(confidence.uppercased())
            .font(.system(size: 9, weight: .black))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func macroTotal(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                if let image = pickedImage {
                    Task { await scanImage(image) }
                }
            } label: {
                Text("Try again")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            if let diagnostic = errorDiagnostic, !diagnostic.isEmpty {
                Button {
                    UIPasteboard.general.string = diagnostic
                    Haptics.success()
                } label: {
                    Label("Copy diagnostic info", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .blueprintCard()
    }

    // MARK: - Logic

    private func scanImage(_ image: UIImage) async {
        isScanning = true
        errorMessage = nil
        errorDiagnostic = nil
        scanResult = nil
        editableItems = []
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            isScanning = false
            errorMessage = FoodScanError.imageTooLarge.errorDescription
            errorDiagnostic = nil
            return
        }
        do {
            let result = try await FoodScanService.scan(data)
            isScanning = false
            scanResult = result
            editableItems = result.items
            suggestedSlot = MealSlot(rawValue: result.suggestedSlot) ?? .snack
            mealSlot = suggestedSlot
            Haptics.success()
        } catch let error as FoodScanError {
            isScanning = false
            errorMessage = error.errorDescription
            errorDiagnostic = error.diagnostic
            Haptics.warning()
        } catch {
            isScanning = false
            errorMessage = "Something went wrong. Please try again."
            errorDiagnostic = "\(error)"
            Haptics.warning()
        }
    }

    private func logItems() {
        let now = Date()
        for item in editableItems {
            appState.addFoodEntry(
                FoodLogEntry(
                    name: item.name,
                    emoji: item.emoji,
                    mealSlot: mealSlot,
                    calories: item.calories,
                    proteinGrams: item.proteinGrams,
                    carbsGrams: item.carbsGrams,
                    fatGrams: item.fatGrams,
                    servings: item.servings,
                    loggedAt: now
                ),
                on: date
            )
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Camera sheet for food scan

private struct FoodScanCameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                FoodScanCamera { image in
                    onCapture(image)
                    dismiss()
                } onClose: {
                    dismiss()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

/// Simple camera view that captures a single photo and returns it.
struct FoodScanCamera: View {
    let onCapture: (UIImage) -> Void
    let onClose: () -> Void

    @State private var session = AVCaptureSession()
    @State private var output = AVCapturePhotoOutput()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var isCapturing: Bool = false
    @State private var photoDelegate: FoodScanCameraDelegate?

    private let captureQueue = DispatchQueue(label: "food-scan-camera")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewLayerView(session: session)

            VStack {
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    Spacer()
                    Text("Take a photo of your meal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 20) {
                    Text("Center your meal in the frame")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Button {
                        capture()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(isCapturing)
                    .opacity(isCapturing ? 0.5 : 1)
                }
                .padding(.bottom, 40)
            }
        }
        .task { setupCamera() }
    }

    private func setupCamera() {
        captureQueue.async {
            session.beginConfiguration()
            session.sessionPreset = .photo

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .back
            )
            guard let device = discovery.devices.first else {
                session.commitConfiguration()
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }
                if session.canAddOutput(output) { session.addOutput(output) }
                session.commitConfiguration()
                DispatchQueue.main.async { session.startRunning() }
            } catch {
                session.commitConfiguration()
            }
        }
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        Haptics.impact(.medium)

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        // Retain the delegate so it isn't deallocated before the photo callback fires.
        let delegate = FoodScanCameraDelegate { image in
            DispatchQueue.main.async {
                isCapturing = false
                photoDelegate = nil
                if let image {
                    onCapture(image)
                }
            }
        }
        photoDelegate = delegate
        output.capturePhoto(with: settings, delegate: delegate)
    }
}

private final class FoodScanCameraDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("[FoodScanCamera] Capture error: \(error.localizedDescription)")
            completion(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}

/// Plain UIKit-backed preview layer.
private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if let connection = uiView.previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
