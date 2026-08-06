import SwiftUI

/// Progress: streak stats, scan timeline, side-by-side compare, and goal overlay.
struct ProgressTabView: View {
    @Environment(AppState.self) private var appState

    @State private var showScanFlow: Bool = false
    @State private var compareLeft: Scan?
    @State private var compareRight: Scan?
    @State private var overlayOpacity: Double = 0.5
    @State private var selectedScanForDetail: Scan?

    private var sortedScans: [Scan] {
        appState.scans.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if appState.scans.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            statsRow
                            goalProjectionCard
                            cycleCard
                            timelineSection
                            if appState.isPro {
                                if sortedScans.count >= 2 {
                                    compareSection
                                }
                                overlaySection
                            } else {
                                proUpsell
                            }
                            DisclaimerFooter()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact()
                        if appState.canStartNewScan {
                            showScanFlow = true
                        } else {
                            appState.showPaywall = true
                        }
                    } label: {
                        Label("New scan", systemImage: "camera.viewfinder")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanFlow) {
                ScanFlowView()
            }
            .sheet(item: $selectedScanForDetail) { scan in
                ResultsView(scan: scan)
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent.opacity(0.6))
            Text("No scans yet")
                .font(.displayFont(24))
                .foregroundStyle(Theme.textPrimary)
            Text("Complete your baseline scan in the Blueprint tab to start tracking.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(appState.weeksCompleted)", label: "WEEKS\nTRAINED", icon: "calendar")
            StatCard(value: "\(appState.streakWeeks)", label: "WEEK\nSTREAK", icon: "flame.fill")
            StatCard(value: "\(appState.scans.count)", label: "SCANS\nDONE", icon: "camera.viewfinder")
        }
    }

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next scan cycle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int(appState.cycleProgress * 100))%")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHi)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(6, geo.size.width * appState.cycleProgress))
                        .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 8)
            Text(appState.rescanDue
                ? "Cycle complete — re-scan to measure your progress."
                : "Complete 4 training weeks, then re-scan to see the change.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .blueprintCard()
    }

    // MARK: - Goal projection

    private var goalProjectionCard: some View {
        Group {
            if let weeks = appState.estimatedWeeksToGoal,
               let goalDate = appState.estimatedGoalDate {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GOAL PROJECTION")
                                .font(.system(size: 11, weight: .black))
                                .tracking(2)
                                .foregroundStyle(Theme.accent)
                            Text("When you'll get there")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Theme.accent.opacity(0.7))
                    }

                    HStack(spacing: 18) {
                        VStack(spacing: 4) {
                            Text("\(weeks)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.accent)
                            Text("WEEKS LEFT")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(width: 1, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated arrival")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.textSecondary)
                            Text(goalDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surfaceHi)
                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(width: max(6, geo.size.width * appState.goalProgress))
                                    .shadow(color: Theme.accent.opacity(0.45), radius: 5)
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text("\(Int(appState.goalProgress * 100))% of the way there")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(appState.weeksCompleted) of \(appState.weeksCompleted + weeks) weeks")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Text("Estimate based on your latest scan, training days, and experience. Re-scan every 4 weeks to sharpen it.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .fill(Theme.surface)
                        .overlay(BlueprintGridBackground(lineColor: Theme.accent.opacity(0.06), spacing: 22).clipShape(.rect(cornerRadius: Theme.cardRadius)))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardRadius)
                                .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Scan timeline", icon: "clock.arrow.circlepath")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(sortedScans) { scan in
                        Button {
                            Haptics.impact(.light)
                            selectedScanForDetail = scan
                        } label: {
                            VStack(spacing: 8) {
                                ScanThumbnail(scan: scan, height: 150, width: 110)
                                Text(scan.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                appState.deleteScan(scan)
                            } label: {
                                Label("Delete scan", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Compare

    private var compareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Compare scans", icon: "square.split.2x1")
            HStack(spacing: 10) {
                ComparePickerColumn(title: "BEFORE", scans: sortedScans, selection: $compareLeft)
                ComparePickerColumn(title: "AFTER", scans: sortedScans, selection: $compareRight)
            }
            if let left = compareLeft ?? sortedScans.first,
               let right = compareRight ?? sortedScans.last {
                HStack(spacing: 10) {
                    VStack(spacing: 6) {
                        ScanThumbnail(scan: left, height: 240)
                        Text(left.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    VStack(spacing: 6) {
                        ScanThumbnail(scan: right, height: 240)
                        Text(right.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(18)
        .blueprintCard()
    }

    // MARK: - Overlay vs target

    private var overlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "You vs. your goal", icon: "scope")
            if let latest = appState.latestScan,
               let goalImage = appState.target?.images.first,
               let goalData = ImageStore.loadData(goalImage.fileName),
               let goal = UIImage(data: goalData) {
                ZStack {
                    ScanThumbnail(scan: latest, height: 320)
                    Theme.surfaceHi
                        .frame(height: 320)
                        .overlay {
                            Image(uiImage: goal)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 16))
                        .opacity(overlayOpacity)
                }
                HStack(spacing: 12) {
                    Text("YOU")
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    Slider(value: $overlayOpacity, in: 0 ... 1)
                        .tint(Theme.accent)
                    Text("GOAL")
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                }
            } else {
                Text("Add a goal photo to unlock the overlay.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .blueprintCard()
    }

    // MARK: - Upsell

    private var proUpsell: some View {
        Button {
            Haptics.impact()
            appState.showPaywall = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent)
                Text("Unlock progress tracking")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Side-by-side comparisons, goal overlay, and unlimited re-scans with Pro.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text("Go Pro")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accent))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .blueprintCard()
        }
    }
}

// MARK: - Components

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .blueprintCard()
    }
}

struct ScanThumbnail: View {
    let scan: Scan
    var height: CGFloat = 200
    var width: CGFloat? = nil

    var body: some View {
        Theme.surfaceHi
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay {
                if let name = scan.frameFileNames.first,
                   let data = ImageStore.loadData(name),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

private struct ComparePickerColumn: View {
    let title: String
    let scans: [Scan]
    @Binding var selection: Scan?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            Menu {
                ForEach(scans) { scan in
                    Button(scan.date.formatted(date: .abbreviated, time: .omitted)) {
                        selection = scan
                    }
                }
            } label: {
                HStack {
                    Text(displayDate)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceHi))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayDate: String {
        let fallback: Scan? = title == "BEFORE" ? scans.first : scans.last
        let scan: Scan? = selection ?? fallback
        guard let scan else { return "—" }
        return scan.date.formatted(date: .abbreviated, time: .omitted)
    }
}
