import SwiftUI

/// An authoritative nutrition reference cited in the app (Guideline 1.4.1).
struct NutritionReference: Identifiable {
    let id: String
    let name: String
    let domain: String
    let url: URL
    let icon: String

    static let all: [NutritionReference] = [
        NutritionReference(
            id: "dga",
            name: "Dietary Guidelines for Americans",
            domain: "dietaryguidelines.gov",
            url: URL(string: "https://www.dietaryguidelines.gov") ?? URL(fileURLWithPath: "/"),
            icon: "flag.fill"
        ),
        NutritionReference(
            id: "myplate",
            name: "USDA MyPlate",
            domain: "myplate.gov",
            url: URL(string: "https://www.myplate.gov") ?? URL(fileURLWithPath: "/"),
            icon: "circle.grid.2x2.fill"
        ),
        NutritionReference(
            id: "eatright",
            name: "Academy of Nutrition and Dietetics",
            domain: "eatright.org",
            url: URL(string: "https://www.eatright.org") ?? URL(fileURLWithPath: "/"),
            icon: "fork.knife"
        ),
        NutritionReference(
            id: "nih",
            name: "National Institutes of Health",
            domain: "nih.gov",
            url: URL(string: "https://www.nih.gov") ?? URL(fileURLWithPath: "/"),
            icon: "cross.case.fill"
        ),
        NutritionReference(
            id: "who",
            name: "World Health Organization",
            domain: "who.int",
            url: URL(string: "https://www.who.int") ?? URL(fileURLWithPath: "/"),
            icon: "globe.americas.fill"
        ),
    ]
}

/// Visible "Sources & References" card shown on nutrition surfaces —
/// calorie/macro targets, meal plans, and diet recommendations (Guideline 1.4.1).
struct NutritionSourcesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("SOURCES & REFERENCES")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(NutritionReference.all) { reference in
                    linkRow(reference)
                    if reference.id != NutritionReference.all.last?.id {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Nutrition guidance is for general informational purposes and is not medical advice. Consult a doctor or registered dietitian.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private func linkRow(_ reference: NutritionReference) -> some View {
        Link(destination: reference.url) {
            HStack(spacing: 12) {
                Image(systemName: reference.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reference.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(reference.domain)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Open \(reference.name) at \(reference.domain)")
    }
}

/// Sheet presentation of the sources list — reachable from a "Sources" toolbar button.
struct NutritionSourcesSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                NutritionSourcesCard()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Nutrition sources")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
    }
}
