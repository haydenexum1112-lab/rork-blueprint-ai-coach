import Foundation

/// Locally regenerates a workout plan when the user changes their training days per week.
/// Redistributes existing AI-generated exercises across the new day count and fills gaps
/// from the ExerciseLibrary, filtered by the user's equipment access.
/// No AI calls — pure local computation.
nonisolated enum PlanRegenerator {

    // MARK: - Public

    /// Returns a new `AnalysisResult` with the plan regenerated for `newDaysPerWeek` training days.
    /// If the day count is unchanged, returns the original analysis unchanged.
    static func regenerate(
        analysis: AnalysisResult,
        newDaysPerWeek: Int,
        equipment: Equipment,
        experience: Experience
    ) -> AnalysisResult {
        let oldPlan = analysis.plan
        guard oldPlan.days.count != newDaysPerWeek else { return analysis }

        // Flatten all existing exercises and group by inferred primary muscle.
        let grouped = groupByMuscle(oldPlan.days.flatMap(\.exercises))

        let template = splitTemplate(for: newDaysPerWeek)
        let newDays = buildDays(
            template: template,
            grouped: grouped,
            equipment: equipment,
            experience: experience
        )

        let newPlan = WorkoutPlan(
            splitName: splitName(for: newDaysPerWeek),
            daysPerWeek: FlexInt(newDaysPerWeek),
            days: newDays
        )

        return AnalysisResult(
            summary: analysis.summary,
            assessment: analysis.assessment,
            gapToGoal: analysis.gapToGoal,
            plan: newPlan,
            physiqueScore: analysis.physiqueScore,
            confidence: analysis.confidence
        )
    }

    // MARK: - Split templates

    struct DayTemplate {
        let name: String
        let targets: [String]
        let muscles: [MuscleGroup]
    }

    static func splitTemplate(for daysPerWeek: Int) -> [DayTemplate] {
        switch daysPerWeek {
        case 2:
            return [
                .init(name: "Upper Body", targets: ["Chest", "Back", "Shoulders", "Arms"], muscles: [.chest, .back, .shoulders, .biceps, .triceps]),
                .init(name: "Lower Body", targets: ["Legs", "Glutes", "Core"], muscles: [.quads, .hamstrings, .glutes, .calves, .core]),
            ]
        case 3:
            return [
                .init(name: "Push", targets: ["Chest", "Shoulders", "Triceps"], muscles: [.chest, .shoulders, .triceps]),
                .init(name: "Pull", targets: ["Back", "Biceps"], muscles: [.back, .biceps]),
                .init(name: "Legs & Core", targets: ["Quads", "Hamstrings", "Glutes", "Core"], muscles: [.quads, .hamstrings, .glutes, .core]),
            ]
        case 4:
            return [
                .init(name: "Upper Push", targets: ["Chest", "Shoulders", "Triceps"], muscles: [.chest, .shoulders, .triceps]),
                .init(name: "Upper Pull", targets: ["Back", "Biceps"], muscles: [.back, .biceps]),
                .init(name: "Lower Quad Focus", targets: ["Quads", "Glutes", "Calves"], muscles: [.quads, .glutes, .calves]),
                .init(name: "Lower Posterior", targets: ["Hamstrings", "Glutes", "Core"], muscles: [.hamstrings, .glutes, .core]),
            ]
        case 5:
            return [
                .init(name: "Chest & Triceps", targets: ["Chest", "Triceps"], muscles: [.chest, .triceps]),
                .init(name: "Back & Biceps", targets: ["Back", "Biceps"], muscles: [.back, .biceps]),
                .init(name: "Legs", targets: ["Quads", "Hamstrings", "Glutes"], muscles: [.quads, .hamstrings, .glutes]),
                .init(name: "Shoulders & Core", targets: ["Shoulders", "Core"], muscles: [.shoulders, .core]),
                .init(name: "Arms & Calves", targets: ["Biceps", "Triceps", "Calves"], muscles: [.biceps, .triceps, .calves]),
            ]
        case 6:
            return [
                .init(name: "Push A", targets: ["Chest", "Shoulders", "Triceps"], muscles: [.chest, .shoulders, .triceps]),
                .init(name: "Pull A", targets: ["Back", "Biceps"], muscles: [.back, .biceps]),
                .init(name: "Legs A", targets: ["Quads", "Hamstrings", "Glutes"], muscles: [.quads, .hamstrings, .glutes]),
                .init(name: "Push B", targets: ["Chest", "Shoulders", "Triceps"], muscles: [.chest, .shoulders, .triceps]),
                .init(name: "Pull B", targets: ["Back", "Biceps"], muscles: [.back, .biceps]),
                .init(name: "Legs B", targets: ["Quads", "Hamstrings", "Glutes"], muscles: [.quads, .hamstrings, .glutes]),
            ]
        default:
            return splitTemplate(for: 4)
        }
    }

    static func splitName(for daysPerWeek: Int) -> String {
        switch daysPerWeek {
        case 2: return "Upper / Lower"
        case 3: return "Push / Pull / Legs"
        case 4: return "Upper / Lower x2"
        case 5: return "Body-Part Split"
        case 6: return "PPL x2"
        default: return "Custom Split"
        }
    }

    // MARK: - Exercise grouping

    /// Groups exercises by their inferred primary muscle group using ExerciseMuscleMap.
    static func groupByMuscle(_ exercises: [Exercise]) -> [MuscleGroup: [Exercise]] {
        var grouped: [MuscleGroup: [Exercise]] = [:]
        for exercise in exercises {
            let muscles = ExerciseMuscleMap.muscles(for: exercise.name)
            let primary = muscles.first ?? .chest
            grouped[primary, default: []].append(exercise)
        }
        return grouped
    }

    // MARK: - Day building

    static func buildDays(
        template: [DayTemplate],
        grouped: [MuscleGroup: [Exercise]],
        equipment: Equipment,
        experience: Experience
    ) -> [WorkoutDay] {
        var usedNames: Set<String> = []
        var pool = grouped
        let targetCount = exerciseTargetCount(for: experience)
        let maxCount = targetCount + 1

        return template.map { dayTemplate in
            var dayExercises: [Exercise] = []

            for muscle in dayTemplate.muscles {
                guard let candidates = pool[muscle] else { continue }
                for exercise in candidates where !usedNames.contains(exercise.name) {
                    dayExercises.append(exercise)
                    usedNames.insert(exercise.name)
                }
                // Remove consumed exercises from the pool
                pool[muscle]?.removeAll { usedNames.contains($0.name) }
            }

            // Fill from library if short
            if dayExercises.count < targetCount {
                let fillers = exercisesFromLibrary(
                    for: dayTemplate.muscles,
                    equipment: equipment,
                    excluding: usedNames
                )
                for ex in fillers {
                    guard dayExercises.count < targetCount else { break }
                    dayExercises.append(ex)
                    usedNames.insert(ex.name)
                }
            }

            // Trim if over max (happens when consolidating to fewer days)
            if dayExercises.count > maxCount {
                dayExercises = Array(dayExercises.prefix(maxCount))
            }

            return WorkoutDay(
                day: dayTemplate.name,
                targets: dayTemplate.targets,
                exercises: dayExercises
            )
        }
    }

    private static func exerciseTargetCount(for experience: Experience) -> Int {
        switch experience {
        case .beginner: return 4
        case .intermediate: return 5
        case .advanced: return 6
        }
    }

    // MARK: - Library conversion

    /// Pulls matching exercises from the ExerciseLibrary, filtered by equipment, and converts to `Exercise`.
    static func exercisesFromLibrary(
        for muscles: [MuscleGroup],
        equipment: Equipment,
        excluding usedNames: Set<String>
    ) -> [Exercise] {
        let allowed = allowedEquipment(for: equipment)

        let matching = ExerciseLibrary.all.filter { def in
            allowed.contains(def.equipment) &&
            muscles.contains(def.primaryMuscle) &&
            !usedNames.contains(def.name)
        }

        return matching.prefix(5).map { def in
            Exercise(
                name: def.name,
                sets: FlexInt(def.defaultSets),
                reps: FlexString("\(def.defaultReps)"),
                restSec: FlexInt(restSeconds(for: def)),
                why: "\(def.primaryMuscle.display) development — targets \(def.primaryMuscle.display.lowercased()) as the primary mover.",
                alt: alternativeName(for: def, equipment: equipment),
                cues: nil
            )
        }
    }

    private static func allowedEquipment(for equipment: Equipment) -> Set<ExerciseEquipment> {
        switch equipment {
        case .fullGym: return Set(ExerciseEquipment.allCases)
        case .homeBasics: return [.dumbbell, .bodyweight, .band, .plate, .kettlebell]
        case .bodyweight: return [.bodyweight]
        }
    }

    private static func restSeconds(for def: ExerciseDefinition) -> Int {
        let lower = def.name.lowercased()
        let isCompound = lower.contains("squat") || lower.contains("deadlift") ||
            lower.contains("bench") || lower.contains("overhead press") ||
            lower.contains("military") || lower.contains("leg press")
        if isCompound || def.defaultReps <= 6 { return 120 }
        if def.defaultReps <= 12 { return 90 }
        return 60
    }

    private static func alternativeName(for def: ExerciseDefinition, equipment: Equipment) -> String? {
        let allowed = allowedEquipment(for: equipment)
        return ExerciseLibrary.all.first { other in
            other.id != def.id &&
            other.primaryMuscle == def.primaryMuscle &&
            allowed.contains(other.equipment) &&
            other.name != def.name
        }?.name
    }
}
