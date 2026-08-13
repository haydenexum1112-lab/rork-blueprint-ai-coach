import Foundation

/// Hardcoded sample analysis result for demo mode. Used by SampleDataLoader
/// so Apple reviewers can always see the app's core features — physique score,
/// region breakdown, and workout plan — even if the AI service is slow or down.
/// The real AI-powered scan path (ScanFlowView → AIService.analyze) is unchanged.
nonisolated enum SampleAnalysisData {

    static let sampleResult: AnalysisResult = AnalysisResult(
        summary: "You show solid foundational development with noticeable strengths in your shoulders and arms. Your back and chest have good width but could use more thickness. Core development lags slightly behind your upper body. With consistent focus on back density, upper chest fullness, and core work, you'll close the gap to your goal physique efficiently.",
        assessment: Assessment(
            strengths: [
                "Well-developed shoulder width and deltoid definition",
                "Balanced arm development with good tricep-bicep ratio",
                "Visible V-taper from both front and back views",
            ],
            focusAreas: [
                FocusArea(region: "back", note: "Add lat thickness and rhomboid detail to match your shoulder width"),
                FocusArea(region: "core", note: "Increase core definition and thickness to match upper-body development"),
                FocusArea(region: "chest", note: "Build upper chest fullness to balance lower pec development"),
            ]
        ),
        gapToGoal: [
            GapItem(region: "back", priority: FlexInt(1), rationale: "Your back has good width but lacks the density and detail seen in your goal references. Prioritize heavy rows and pull-ups to add thickness."),
            GapItem(region: "chest", priority: FlexInt(2), rationale: "Upper chest development will create a fuller, more balanced look from the front. Incline work is key here."),
            GapItem(region: "core", priority: FlexInt(3), rationale: "Core work will bring your midsection in line with your well-developed upper body and improve overall proportion."),
            GapItem(region: "legs", priority: FlexInt(4), rationale: "Legs are solid but could use more quad sweep and hamstring separation for full-body proportion."),
        ],
        plan: WorkoutPlan(
            splitName: "Push/Pull/Legs + Upper/Lower 5-day",
            daysPerWeek: FlexInt(5),
            days: [
                WorkoutDay(
                    day: "Day 1 — Push (Chest, Shoulders, Triceps)",
                    targets: ["chest", "shoulders", "triceps"],
                    exercises: [
                        Exercise(name: "Incline Dumbbell Press", sets: FlexInt(4), reps: FlexString("8-10"), restSec: FlexInt(120), why: "Builds upper chest fullness — your #2 gap to goal", alt: "Machine Incline Press", cues: ["Lower dumbbells to chest level", "Drive through the heels", "Squeeze hard at the top"]),
                        Exercise(name: "Seated Overhead Dumbbell Press", sets: FlexInt(3), reps: FlexString("8-10"), restSec: FlexInt(90), why: "Maintains your shoulder width — a current strength", alt: "Smith Machine Overhead Press", cues: ["Keep elbows slightly forward", "Press straight overhead", "Don't arch the lower back"]),
                        Exercise(name: "Cable Crossover", sets: FlexInt(3), reps: FlexString("12-15"), restSec: FlexInt(60), why: "Adds chest detail and definition for balanced pecs", alt: "Pec Deck Fly", cues: ["Squeeze at midpoint", "Keep slight bend in elbows", "Control the negative"]),
                        Exercise(name: "Dumbbell Lateral Raise", sets: FlexInt(3), reps: FlexString("12-15"), restSec: FlexInt(60), why: "Preserves deltoid definition — a key asset", alt: "Cable Lateral Raise", cues: ["Lead with the elbows", "Don't swing", "Pause briefly at the top"]),
                        Exercise(name: "Tricep Rope Pushdown", sets: FlexInt(3), reps: FlexString("10-12"), restSec: FlexInt(60), why: "Balances tricep development for arm proportion", alt: "Overhead Tricep Extension", cues: ["Keep elbows tucked", "Spread the rope at the bottom", "Full extension at the bottom"]),
                    ]
                ),
                WorkoutDay(
                    day: "Day 2 — Pull (Back, Biceps)",
                    targets: ["back", "biceps"],
                    exercises: [
                        Exercise(name: "Lat Pulldown", sets: FlexInt(4), reps: FlexString("8-10"), restSec: FlexInt(90), why: "Builds back width to match your shoulders", alt: "Assisted Pull-Up", cues: ["Pull to upper chest", "Squeeze shoulder blades together", "Control the negative"]),
                        Exercise(name: "Barbell Row", sets: FlexInt(4), reps: FlexString("8-10"), restSec: FlexInt(120), why: "Targets back thickness — your #1 gap to goal", alt: "T-Bar Row", cues: ["Hinge at the hips", "Pull to lower rib cage", "Keep core tight throughout"]),
                        Exercise(name: "Seated Cable Row", sets: FlexInt(3), reps: FlexString("10-12"), restSec: FlexInt(90), why: "Adds mid-back detail and rhomboid engagement", alt: "Chest-Supported Row", cues: ["Pull elbows straight back", "Squeeze at full contraction", "Don't lean back excessively"]),
                        Exercise(name: "Face Pull", sets: FlexInt(3), reps: FlexString("15-20"), restSec: FlexInt(60), why: "Strengthens rear delts and improves posture", alt: "Reverse Pec Deck", cues: ["Pull rope to forehead", "Spread the rope apart", "Squeeze rear delts hard"]),
                        Exercise(name: "Barbell Curl", sets: FlexInt(3), reps: FlexString("8-10"), restSec: FlexInt(60), why: "Maintains bicep development — a current strength", alt: "Dumbbell Curl", cues: ["Keep elbows pinned to sides", "Full range of motion", "Don't swing the weight up"]),
                    ]
                ),
                WorkoutDay(
                    day: "Day 3 — Legs & Core",
                    targets: ["legs", "core"],
                    exercises: [
                        Exercise(name: "Barbell Back Squat", sets: FlexInt(4), reps: FlexString("6-8"), restSec: FlexInt(150), why: "Builds overall leg strength and quad sweep", alt: "Leg Press", cues: ["Sit back into the squat", "Knees track over toes", "Drive through midfoot"]),
                        Exercise(name: "Romanian Deadlift", sets: FlexInt(3), reps: FlexString("8-10"), restSec: FlexInt(120), why: "Develops hamstrings and glutes for leg proportion", alt: "Leg Curl", cues: ["Hinge at the hips", "Keep bar close to body", "Slight knee bend throughout"]),
                        Exercise(name: "Walking Lunge", sets: FlexInt(3), reps: FlexString("12-15"), restSec: FlexInt(90), why: "Improves leg separation and balance", alt: "Dumbbell Split Squat", cues: ["Step forward and lower", "Keep torso upright", "Push through front heel"]),
                        Exercise(name: "Leg Curl", sets: FlexInt(3), reps: FlexString("12-15"), restSec: FlexInt(60), why: "Targets hamstring detail — a gap area", alt: "Glute-Ham Raise", cues: ["Curl slowly with control", "Squeeze at the top", "Resist the negative"]),
                        Exercise(name: "Hanging Leg Raise", sets: FlexInt(3), reps: FlexString("12-15"), restSec: FlexInt(60), why: "Builds core strength — your #3 gap to goal", alt: "Cable Crunch", cues: ["Lift legs with control", "Don't swing or kip", "Lower slowly to full hang"]),
                    ]
                ),
                WorkoutDay(
                    day: "Day 4 — Upper Body (Chest, Back, Shoulders, Arms)",
                    targets: ["chest", "back", "shoulders", "arms"],
                    exercises: [
                        Exercise(name: "Flat Dumbbell Press", sets: FlexInt(4), reps: FlexString("8-10"), restSec: FlexInt(90), why: "Maintains chest thickness to balance upper chest work", alt: "Barbell Bench Press", cues: ["Lower to chest level", "Drive up and together", "Keep shoulders pulled back"]),
                        Exercise(name: "Pull-Up", sets: FlexInt(4), reps: FlexString("6-10"), restSec: FlexInt(90), why: "Compound back builder — directly targets your #1 gap", alt: "Assisted Pull-Up", cues: ["Pull chin over the bar", "Control the descent", "Full hang at the bottom"]),
                        Exercise(name: "Arnold Press", sets: FlexInt(3), reps: FlexString("10-12"), restSec: FlexInt(75), why: "Full-range shoulder development — preserves your strength", alt: "Dumbbell Shoulder Press", cues: ["Rotate palms during the press", "Full overhead lockout", "Control the descent"]),
                        Exercise(name: "Seated Cable Row", sets: FlexInt(3), reps: FlexString("10-12"), restSec: FlexInt(75), why: "Extra back volume for thickness — your priority area", alt: "Chest-Supported Row", cues: ["Pull to lower ribs", "Squeeze shoulder blades", "Don't use momentum"]),
                        Exercise(name: "Hammer Curl + Tricep Dip Superset", sets: FlexInt(3), reps: FlexString("10-12"), restSec: FlexInt(60), why: "Balanced arm work to maintain your strength", alt: "Preacher Curl + Bench Dip", cues: ["Curl: keep elbows fixed at sides", "Dip: lean forward slightly for chest", "Minimal rest between the pair"]),
                    ]
                ),
                WorkoutDay(
                    day: "Day 5 — Lower Body & Core",
                    targets: ["legs", "core"],
                    exercises: [
                        Exercise(name: "Front Squat", sets: FlexInt(4), reps: FlexString("6-8"), restSec: FlexInt(120), why: "Targets quads and core for balanced leg development", alt: "Goblet Squat", cues: ["Keep elbows high", "Stay upright in the torso", "Deep controlled range of motion"]),
                        Exercise(name: "Hip Thrust", sets: FlexInt(4), reps: FlexString("8-10"), restSec: FlexInt(90), why: "Builds glute strength for posterior chain balance", alt: "Glute Bridge", cues: ["Drive through the heels", "Squeeze hard at the top", "Full hip extension"]),
                        Exercise(name: "Standing Calf Raise", sets: FlexInt(4), reps: FlexString("15-20"), restSec: FlexInt(60), why: "Develops calf size for full-leg proportion", alt: "Seated Calf Raise", cues: ["Full stretch at the bottom", "Pause at the top", "Don't bounce the weight"]),
                        Exercise(name: "Cable Crunch", sets: FlexInt(3), reps: FlexString("15-20"), restSec: FlexInt(60), why: "Targets core definition — your #3 gap to goal", alt: "Hanging Leg Raise", cues: ["Curl spine downward", "Squeeze abs hard at the bottom", "Control the negative"]),
                        Exercise(name: "Plank", sets: FlexInt(3), reps: FlexString("45-60s"), restSec: FlexInt(60), why: "Builds core stability and midsection control", alt: "Ab Wheel Rollout", cues: ["Keep body in a straight line", "Don't let hips sag", "Brace the core throughout"]),
                    ]
                ),
            ]
        ),
        physiqueScore: PhysiqueScore(
            overall: FlexInt(72),
            byRegion: [
                "chest": FlexInt(70),
                "shoulders": FlexInt(78),
                "back": FlexInt(68),
                "arms": FlexInt(75),
                "legs": FlexInt(70),
                "core": FlexInt(65),
            ]
        ),
        confidence: "medium"
    )

    /// Encodes the sample result to a pretty-printed JSON string for the Scan's `rawJSON` field.
    static var sampleRawJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sampleResult),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
