import PhotosUI
import SwiftUI

/// Full onboarding: value-prop slides, then a stepped profile form with an 18+ gate.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    private enum Step: Int, CaseIterable {
        case slides
        case identity
        case body
        case training
        case goals
        case goalPhotos
    }

    @State private var step: Step = .slides
    @State private var slideIndex: Int = 0

    @State private var name: String = ""
    @State private var age: Int = 25
    @State private var sex: Sex = .male
    @State private var usesMetric: Bool = false
    @State private var heightCm: Double = 178
    @State private var weightKg: Double = 80
    @State private var experience: Experience = .beginner
    @State private var daysPerWeek: Int = 4
    @State private var equipment: Equipment = .fullGym
    @State private var goalTags: Set<GoalTag> = []

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            PhyziqAiGridBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if step != .slides {
                    stepHeader
                }

                switch step {
                case .slides:
                    slidesSection
                case .identity:
                    identityStep
                case .body:
                    bodyStep
                case .training:
                    trainingStep
                case .goals:
                    goalsStep
                case .goalPhotos:
                    goalPhotosStep
                }
            }
        }
    }

    // MARK: - Slides

    private var slidesSection: some View {
        VStack(spacing: 0) {
            TabView(selection: $slideIndex) {
                OnboardingSlide(
                    icon: "viewfinder",
                    title: "See yourself\nclearly.",
                    subtitle: "Scan your physique with your camera. AI maps where you are today — honestly, privately, on your phone."
                )
                .tag(0)
                OnboardingSlide(
                    icon: "scope",
                    title: "Set the\ntarget.",
                    subtitle: "Upload photos of the physique you're chasing. PhyziqAi measures the gap between you and your goal."
                )
                .tag(1)
                OnboardingSlide(
                    icon: "square.grid.2x2",
                    title: "Get your\nplan.",
                    subtitle: "A week-by-week training plan engineered to close that gap — built for your body, your gym, your schedule."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Capsule()
                        .fill(index == slideIndex ? Theme.accent : Theme.surfaceHi)
                        .frame(width: index == slideIndex ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: slideIndex)
                }
            }
            .padding(.bottom, 24)

            Button(slideIndex < 2 ? "Continue" : "Build my plan") {
                Haptics.impact(.light)
                if slideIndex < 2 {
                    withAnimation { slideIndex += 1 }
                } else {
                    withAnimation { step = .identity }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Header

    private var stepHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.impact(.light)
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                Spacer()
                Text("BLUEPRINT")
                    .font(.system(size: 13, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHi)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private var progressFraction: CGFloat {
        switch step {
        case .slides: return 0
        case .identity: return 0.25
        case .body: return 0.5
        case .training: return 0.75
        case .goals: return 0.85
        case .goalPhotos: return 1
        }
    }

    private func goBack() {
        withAnimation {
            switch step {
            case .slides: break
            case .identity: step = .slides
            case .body: step = .identity
            case .training: step = .body
            case .goals: step = .training
            case .goalPhotos: step = .goals
            }
        }
    }

    // MARK: - Identity step

    private var isAdult: Bool { age >= 18 }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingStepTitle(title: "First, the basics", subtitle: "Your plan is built around you.")

            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Theme.textSecondary))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(16)
                    .blueprintCard()
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AGE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Picker("Age", selection: $age) {
                    ForEach(13 ... 90, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .blueprintCard()
            }

            if !isAdult {
                Label("PhyziqAi is designed for adults 18 and over.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warning.opacity(0.12)))
            }

            Spacer()

            Button("Continue") {
                Haptics.impact(.light)
                withAnimation { step = .body }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !isAdult)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty || !isAdult ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Body step

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingStepTitle(title: "Your frame", subtitle: "Used to calibrate the analysis.")

            Picker("Sex", selection: $sex) {
                ForEach(Sex.allCases) { option in
                    Text(option.display).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Picker("Units", selection: $usesMetric) {
                Text("ft / lb").tag(false)
                Text("cm / kg").tag(true)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                MeasurePickerCard(label: "HEIGHT", value: heightMeasureBinding, options: heightOptions)
                MeasurePickerCard(label: "WEIGHT", value: weightMeasureBinding, options: weightOptions)
            }

            Spacer()

            Button("Continue") {
                Haptics.impact(.light)
                withAnimation { step = .training }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var heightOptions: [MeasureOption] {
        var options: [MeasureOption] = []
        if usesMetric {
            for cm in 130 ... 220 {
                options.append(MeasureOption(label: "\(cm) cm", canonical: Double(cm)))
            }
            return options
        }
        for feet in 4 ... 7 {
            for inches in 0 ... 11 {
                let cm: Double = Double(feet * 12 + inches) * 2.54
                options.append(MeasureOption(label: "\(feet)′\(inches)″", canonical: cm))
            }
        }
        return options
    }

    private var weightOptions: [MeasureOption] {
        var options: [MeasureOption] = []
        if usesMetric {
            for kg in 40 ... 180 {
                options.append(MeasureOption(label: "\(kg) kg", canonical: Double(kg)))
            }
            return options
        }
        for lb in 90 ... 400 {
            options.append(MeasureOption(label: "\(lb) lb", canonical: Double(lb) / 2.20462))
        }
        return options
    }

    private var heightMeasureBinding: Binding<Double> {
        Binding(
            get: { heightCm },
            set: { heightCm = $0 }
        )
    }

    private var weightMeasureBinding: Binding<Double> {
        Binding(
            get: { weightKg },
            set: { weightKg = $0 }
        )
    }

    // MARK: - Training step

    private var trainingStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingStepTitle(title: "How you train", subtitle: "Your plan fits your real schedule and gear.")

                VStack(alignment: .leading, spacing: 10) {
                    Text("EXPERIENCE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(Experience.allCases) { option in
                        SelectableRow(
                            title: option.display,
                            subtitle: option.subtitle,
                            icon: "chart.bar.fill",
                            isSelected: experience == option
                        ) {
                            experience = option
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("TRAINING DAYS PER WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(2 ... 6, id: \.self) { day in
                            Button {
                                Haptics.impact(.light)
                                daysPerWeek = day
                            } label: {
                                Text("\(day)")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(daysPerWeek == day ? Color.black : Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(daysPerWeek == day ? Theme.accent : Theme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(daysPerWeek == day ? Color.clear : Theme.hairline, lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("EQUIPMENT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(Equipment.allCases) { option in
                        SelectableRow(
                            title: option.display,
                            subtitle: option.subtitle,
                            icon: option.icon,
                            isSelected: equipment == option
                        ) {
                            equipment = option
                        }
                    }
                }

                Button("Continue") {
                    Haptics.impact(.light)
                    withAnimation { step = .goals }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Goals step

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingStepTitle(title: "What are you chasing?", subtitle: "Pick everything that applies.")

            VStack(spacing: 10) {
                ForEach(GoalTag.allCases) { tag in
                    SelectableRow(
                        title: tag.display,
                        subtitle: nil,
                        icon: goalTags.contains(tag) ? "checkmark.circle.fill" : "circle",
                        isSelected: goalTags.contains(tag)
                    ) {
                        if goalTags.contains(tag) {
                            goalTags.remove(tag)
                        } else {
                            goalTags.insert(tag)
                        }
                    }
                }
            }

            Spacer()

            Button("Continue") {
                Haptics.impact(.light)
                withAnimation { step = .goalPhotos }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(goalTags.isEmpty)
            .opacity(goalTags.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Goal photos step

    @State private var goalPickerItems: [PhotosPickerItem] = []
    @State private var goalDrafts: [GoalDraft] = []
    @State private var isLoadingGoalPhotos: Bool = false

    private struct GoalDraft: Identifiable {
        let id = UUID()
        let data: Data
        let image: UIImage
    }

    private var goalPhotosStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStepTitle(
                    title: "Your target physique",
                    subtitle: "Upload 1–3 photos of the body you're working toward."
                )

                Text("Physique athletes, fitness models, or anyone whose build inspires you. PhyziqAi uses these to measure your gap and engineer your plan.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if goalDrafts.isEmpty {
                    PhotosPicker(selection: $goalPickerItems, maxSelectionCount: 3, matching: .images) {
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
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(goalDrafts) { draft in
                            Theme.surfaceHi
                                .frame(height: 170)
                                .overlay {
                                    Image(uiImage: draft.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadius: 14))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        Haptics.impact(.light)
                                        goalDrafts.removeAll { $0.id == draft.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(.black.opacity(0.55)))
                                    }
                                    .padding(8)
                                }
                        }
                    }

                    if goalDrafts.count < 3 {
                        PhotosPicker(selection: $goalPickerItems, maxSelectionCount: 3 - goalDrafts.count, matching: .images) {
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

                if isLoadingGoalPhotos {
                    HStack {
                        Spacer()
                        SwiftUI.ProgressView()
                            .tint(Theme.accent)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Spacer(minLength: 12)

                Button {
                    Haptics.success()
                    finish()
                } label: {
                    HStack {
                        Text(goalDrafts.isEmpty ? "Skip for now" : "Create my plan")
                        if !goalDrafts.isEmpty {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onChange(of: goalPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            loadGoalPicked(newItems)
        }
    }

    private func loadGoalPicked(_ items: [PhotosPickerItem]) {
        isLoadingGoalPhotos = true
        Task {
            for item in items {
                guard goalDrafts.count < 3 else { break }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let resized = ImageResizer.resize(data, maxBytes: 900_000),
                   let image = UIImage(data: resized) {
                    goalDrafts.append(GoalDraft(data: resized, image: image))
                }
            }
            goalPickerItems = []
            isLoadingGoalPhotos = false
        }
    }

    private func finish() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            usesMetric: usesMetric,
            experience: experience,
            daysPerWeek: daysPerWeek,
            equipment: equipment,
            goalTags: Array(goalTags)
        )
        appState.saveProfile(profile)

        if !goalDrafts.isEmpty {
            var saved: [TargetImage] = []
            for draft in goalDrafts {
                if let fileName = ImageStore.save(draft.data) {
                    saved.append(TargetImage(fileName: fileName, caption: ""))
                }
            }
            if !saved.isEmpty {
                appState.saveTarget(TargetReference(images: saved))
            }
        }
    }
}

// MARK: - Components

private struct OnboardingSlide: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .shadow(color: Theme.accent.opacity(0.25), radius: 30)

            Text(title)
                .font(.displayFont(44))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }
}

private struct OnboardingStepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.displayFont(30))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct SelectableRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }
}

struct MeasureOption: Identifiable {
    let label: String
    let canonical: Double

    var id: Double { canonical }
}

private struct MeasurePickerCard: View {
    let label: String
    @Binding var value: Double
    let options: [MeasureOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            Picker(label, selection: $value) {
                ForEach(options) { option in
                    Text(option.label)
                        .font(.system(size: 18, weight: .bold))
                        .tag(option.canonical)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 130)
            .blueprintCard()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            snapToNearest()
        }
    }

    private func snapToNearest() {
        guard !options.isEmpty else { return }
        if let nearest = options.min(by: { abs($0.canonical - value) < abs($1.canonical - value) }) {
            value = nearest.canonical
        }
    }
}
