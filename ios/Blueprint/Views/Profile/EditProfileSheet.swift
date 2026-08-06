import SwiftUI

/// Edit body stats and training preferences after onboarding.
struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                        .foregroundStyle(Theme.textPrimary)
                    Picker("Age", selection: $age) {
                        ForEach(18 ... 90, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { option in
                            Text(option.display).tag(option)
                        }
                    }
                }

                Section("Body") {
                    Toggle("Use metric units", isOn: $usesMetric)
                    if usesMetric {
                        Picker("Height", selection: $heightCm) {
                            ForEach(130 ... 220, id: \.self) { cm in
                                Text("\(cm) cm").tag(Double(cm))
                            }
                        }
                        Picker("Weight", selection: Binding(
                            get: { Int(weightKg.rounded()) },
                            set: { weightKg = Double($0) }
                        )) {
                            ForEach(40 ... 180, id: \.self) { kg in
                                Text("\(kg) kg").tag(kg)
                            }
                        }
                    } else {
                        Picker("Height", selection: Binding(
                            get: { Int((heightCm / 2.54).rounded()) },
                            set: { heightCm = Double($0) * 2.54 }
                        )) {
                            ForEach(48 ... 95, id: \.self) { inches in
                                Text("\(inches / 12)′\(inches % 12)″").tag(inches)
                            }
                        }
                        Picker("Weight", selection: Binding(
                            get: { Int((weightKg * 2.20462).rounded()) },
                            set: { weightKg = Double($0) / 2.20462 }
                        )) {
                            ForEach(90 ... 400, id: \.self) { lb in
                                Text("\(lb) lb").tag(lb)
                            }
                        }
                    }
                }

                Section("Training") {
                    Picker("Experience", selection: $experience) {
                        ForEach(Experience.allCases) { option in
                            Text(option.display).tag(option)
                        }
                    }
                    Stepper("Days per week: \(daysPerWeek)", value: $daysPerWeek, in: 2 ... 6)
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { option in
                            Text(option.display).tag(option)
                        }
                    }
                }

                Section("Goals") {
                    ForEach(GoalTag.allCases) { tag in
                        Button {
                            if goalTags.contains(tag) {
                                goalTags.remove(tag)
                            } else {
                                goalTags.insert(tag)
                            }
                        } label: {
                            HStack {
                                Text(tag.display)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if goalTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("Changes apply to your next scan and plan. Your current plan stays as-is until you re-scan.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.success()
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || goalTags.isEmpty)
                }
            }
            .onAppear(perform: loadCurrent)
        }
        
    }

    private func loadCurrent() {
        guard let profile = appState.profile else { return }
        name = profile.name
        age = max(18, profile.age)
        sex = profile.sex
        usesMetric = profile.usesMetric
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        experience = profile.experience
        daysPerWeek = profile.daysPerWeek
        equipment = profile.equipment
        goalTags = Set(profile.goalTags)
    }

    private func save() {
        guard var profile = appState.profile else { return }
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.age = age
        profile.sex = sex
        profile.usesMetric = usesMetric
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.experience = experience
        profile.daysPerWeek = daysPerWeek
        profile.equipment = equipment
        profile.goalTags = Array(goalTags)
        appState.saveProfile(profile)
        dismiss()
    }
}
