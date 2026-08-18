import Foundation

/// Equipment categories for exercise filtering.
nonisolated enum ExerciseEquipment: String, Codable, CaseIterable, Identifiable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case band
    case plate
    case other

    var id: String { rawValue }

    var display: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .band: return "Band"
        case .plate: return "Plate"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .barbell: return "barbell.fill"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.fill"
        case .cable: return "cable.connector"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .kettlebell: return "scalemass.fill"
        case .band: return "circle.dashed"
        case .plate: return "circle.fill"
        case .other: return "questionmark.circle"
        }
    }
}

/// A single exercise definition in the library.
nonisolated struct ExerciseDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: ExerciseEquipment

    /// Suggested default sets and reps for quick logging.
    let defaultSets: Int
    let defaultReps: Int
}

/// Comprehensive exercise library organized by muscle group.
/// Used by the exercise picker when logging freeform workouts.
nonisolated enum ExerciseLibrary {

    static let all: [ExerciseDefinition] = chest + back + shoulders + biceps + triceps +
        quads + hamstrings + glutes + core + calves + fullBody + forearms + cardio

    // MARK: - Chest

    static let chest: [ExerciseDefinition] = [
        .init(id: "barbell_bench_press", name: "Barbell Bench Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "incline_barbell_bench", name: "Incline Barbell Bench Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "decline_barbell_bench", name: "Decline Barbell Bench Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "dumbbell_bench_press", name: "Dumbbell Bench Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "incline_dumbbell_press", name: "Incline Dumbbell Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "decline_dumbbell_press", name: "Decline Dumbbell Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "dumbbell_fly", name: "Dumbbell Fly", primaryMuscle: .chest, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "incline_dumbbell_fly", name: "Incline Dumbbell Fly", primaryMuscle: .chest, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_crossover", name: "Cable Crossover", primaryMuscle: .chest, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "low_cable_fly", name: "Low Cable Fly", primaryMuscle: .chest, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "high_to_low_cable_fly", name: "High-to-Low Cable Fly", primaryMuscle: .chest, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "machine_chest_press", name: "Machine Chest Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "incline_machine_press", name: "Incline Machine Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "pec_deck", name: "Pec Deck Machine", primaryMuscle: .chest, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "smith_bench_press", name: "Smith Machine Bench Press", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .machine, defaultSets: 4, defaultReps: 8),
        .init(id: "smith_incline_press", name: "Smith Machine Incline Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .machine, defaultSets: 4, defaultReps: 8),
        .init(id: "push_up", name: "Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps, .core], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "diamond_push_up", name: "Diamond Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "incline_push_up", name: "Incline Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "decline_push_up", name: "Decline Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "wide_push_up", name: "Wide Push-Up", primaryMuscle: .chest, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "archer_push_up", name: "Archer Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "explosive_push_up", name: "Explosive Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 10),
        .init(id: "weighted_push_up", name: "Weighted Push-Up", primaryMuscle: .chest, secondaryMuscles: [.triceps, .core], equipment: .plate, defaultSets: 4, defaultReps: 10),
        .init(id: "dips_chest", name: "Chest Dips", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .bodyweight, defaultSets: 3, defaultReps: 10),
        .init(id: "weighted_dips", name: "Weighted Dips", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .plate, defaultSets: 4, defaultReps: 8),
        .init(id: "plate_press", name: "Plate Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .plate, defaultSets: 3, defaultReps: 12),
        .init(id: "band_chest_press", name: "Band Chest Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "band_fly", name: "Band Fly", primaryMuscle: .chest, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "medicine_ball_chest_throw", name: "Medicine Ball Chest Throw", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .other, defaultSets: 3, defaultReps: 12),
        .init(id: "flat_db_squeeze_press", name: "Dumbbell Squeeze Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "hex_press", name: "Hex Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_chest_press", name: "Cable Chest Press", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
    ]

    // MARK: - Back

    static let back: [ExerciseDefinition] = [
        .init(id: "conventional_deadlift", name: "Conventional Deadlift", primaryMuscle: .back, secondaryMuscles: [.hamstrings, .glutes, .core], equipment: .barbell, defaultSets: 4, defaultReps: 5),
        .init(id: "sumo_deadlift", name: "Sumo Deadlift", primaryMuscle: .back, secondaryMuscles: [.glutes, .hamstrings], equipment: .barbell, defaultSets: 4, defaultReps: 5),
        .init(id: "trap_bar_deadlift", name: "Trap Bar Deadlift", primaryMuscle: .back, secondaryMuscles: [.quads, .glutes], equipment: .barbell, defaultSets: 4, defaultReps: 5),
        .init(id: "rack_pull", name: "Rack Pull", primaryMuscle: .back, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "deficit_deadlift", name: "Deficit Deadlift", primaryMuscle: .back, secondaryMuscles: [.hamstrings], equipment: .barbell, defaultSets: 4, defaultReps: 5),
        .init(id: "barbell_row", name: "Barbell Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "pendlay_row", name: "Pendlay Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "t_bar_row", name: "T-Bar Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: " Meadows_row", name: "Meadows Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "dumbbell_row", name: "Dumbbell Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "two_arm_db_row", name: "Two-Arm Dumbbell Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "chest_supported_db_row", name: "Chest-Supported Dumbbell Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "lat_pulldown", name: "Lat Pulldown", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "wide_grip_lat_pulldown", name: "Wide-Grip Lat Pulldown", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "close_grip_lat_pulldown", name: "Close-Grip Lat Pulldown", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "reverse_grip_pulldown", name: "Reverse Grip Pulldown", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "seated_cable_row", name: "Seated Cable Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "close_grip_cable_row", name: "Close-Grip Cable Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "wide_grip_cable_row", name: "Wide-Grip Cable Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 4, defaultReps: 10),
        .init(id: "single_arm_cable_row", name: "Single-Arm Cable Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "face_pull", name: "Face Pull", primaryMuscle: .back, secondaryMuscles: [.shoulders], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "straight_arm_pulldown", name: "Straight-Arm Pulldown", primaryMuscle: .back, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "machine_row", name: "Machine Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "hammer_strength_row", name: "Hammer Strength Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "smith_row", name: "Smith Machine Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .machine, defaultSets: 4, defaultReps: 8),
        .init(id: "pull_up", name: "Pull-Up", primaryMuscle: .back, secondaryMuscles: [.biceps, .core], equipment: .bodyweight, defaultSets: 4, defaultReps: 8),
        .init(id: "chin_up", name: "Chin-Up", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .bodyweight, defaultSets: 4, defaultReps: 8),
        .init(id: "wide_grip_pull_up", name: "Wide-Grip Pull-Up", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .bodyweight, defaultSets: 4, defaultReps: 8),
        .init(id: "weighted_pull_up", name: "Weighted Pull-Up", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .plate, defaultSets: 4, defaultReps: 6),
        .init(id: "inverse_row", name: "Inverse Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "superman", name: "Superman", primaryMuscle: .back, secondaryMuscles: [.core], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "band_row", name: "Band Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "band_lat_pulldown", name: "Band Lat Pulldown", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "kettlebell_row", name: "Kettlebell Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "renegade_row", name: "Renegade Row", primaryMuscle: .back, secondaryMuscles: [.core, .biceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "single_arm_landmine_row", name: "Single-Arm Landmine Row", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "shrug", name: "Barbell Shrug", primaryMuscle: .back, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 12),
        .init(id: "dumbbell_shrug", name: "Dumbbell Shrug", primaryMuscle: .back, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 12),
        .init(id: "cable_shrug", name: "Cable Shrug", primaryMuscle: .back, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
    ]

    // MARK: - Shoulders

    static let shoulders: [ExerciseDefinition] = [
        .init(id: "overhead_press", name: "Overhead Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps, .core], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "military_press", name: "Military Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "push_press", name: "Push Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps, .quads], equipment: .barbell, defaultSets: 4, defaultReps: 6),
        .init(id: "behind_neck_press", name: "Behind the Neck Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .barbell, defaultSets: 3, defaultReps: 8),
        .init(id: "seated_db_press", name: "Seated Dumbbell Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "standing_db_press", name: "Standing Dumbbell Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps, .core], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "arnold_press", name: "Arnold Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "lateral_raise", name: "Lateral Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 15),
        .init(id: "cable_lateral_raise", name: "Cable Lateral Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "machine_lateral_raise", name: "Machine Lateral Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "front_raise", name: "Front Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_front_raise", name: "Cable Front Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "plate_front_raise", name: "Plate Front Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .plate, defaultSets: 3, defaultReps: 15),
        .init(id: "rear_delt_fly", name: "Rear Delt Fly", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "rear_delt_machine", name: "Reverse Pec Deck", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_reverse_fly", name: "Cable Reverse Fly", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "upright_row", name: "Upright Row", primaryMuscle: .shoulders, secondaryMuscles: [.biceps, .back], equipment: .barbell, defaultSets: 3, defaultReps: 12),
        .init(id: "db_upright_row", name: "Dumbbell Upright Row", primaryMuscle: .shoulders, secondaryMuscles: [.biceps], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_upright_row", name: "Cable Upright Row", primaryMuscle: .shoulders, secondaryMuscles: [.biceps], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "machine_shoulder_press", name: "Machine Shoulder Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "smith_ohp", name: "Smith Machine Overhead Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .machine, defaultSets: 4, defaultReps: 8),
        .init(id: "pike_push_up", name: "Pike Push-Up", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "handstand_push_up", name: "Handstand Push-Up", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "band_lateral_raise", name: "Band Lateral Raise", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "band_press", name: "Band Shoulder Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "kettlebell_press", name: "Kettlebell Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .kettlebell, defaultSets: 4, defaultReps: 8),
        .init(id: "kettlebell_clean_press", name: "Kettlebell Clean and Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps, .back], equipment: .kettlebell, defaultSets: 4, defaultReps: 8),
        .init(id: "landmine_press", name: "Landmine Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "single_arm_landmine_press", name: "Single-Arm Landmine Press", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "y_raise", name: "Y-Raise", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "cuban_press", name: "Cuban Press", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "external_rotation", name: "External Rotation", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
    ]

    // MARK: - Biceps

    static let biceps: [ExerciseDefinition] = [
        .init(id: "barbell_curl", name: "Barbell Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "ez_bar_curl", name: "EZ Bar Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "dumbbell_curl", name: "Dumbbell Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "alternating_db_curl", name: "Alternating Dumbbell Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "hammer_curl", name: "Hammer Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 12),
        .init(id: "incline_db_curl", name: "Incline Dumbbell Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "preacher_curl", name: "Preacher Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "ez_preacher_curl", name: "EZ Bar Preacher Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "db_preacher_curl", name: "Dumbbell Preacher Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "concentration_curl", name: "Concentration Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "spider_curl", name: "Spider Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "drag_curl", name: "Drag Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_curl", name: "Cable Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "low_pulley_curl", name: "Low Pulley Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "rope_hammer_curl", name: "Rope Hammer Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "high_pulley_curl", name: "High Pulley Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "machine_preacher_curl", name: "Machine Preacher Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 12),
        .init(id: "machine_bicep_curl", name: "Machine Bicep Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 12),
        .init(id: "chin_up_biceps", name: "Chin-Up (Biceps Focus)", primaryMuscle: .biceps, secondaryMuscles: [.back], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "towel_curl", name: "Towel Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "band_curl", name: "Band Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "bayesian_curl", name: "Bayesian Cable Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "cross_body_hammer", name: "Cross-Body Hammer Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "reverse_curl", name: "Reverse Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 3, defaultReps: 12),
        .init(id: "db_reverse_curl", name: "Dumbbell Reverse Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "zottman_curl", name: "Zottman Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "21s_curl", name: "21s Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 3, defaultReps: 7),
    ]

    // MARK: - Triceps

    static let triceps: [ExerciseDefinition] = [
        .init(id: "close_grip_bench", name: "Close-Grip Bench Press", primaryMuscle: .triceps, secondaryMuscles: [.chest, .shoulders], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "jm_press", name: "JM Press", primaryMuscle: .triceps, secondaryMuscles: [.chest], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "skull_crusher", name: "Skull Crusher", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 12),
        .init(id: "ez_skull_crusher", name: "EZ Bar Skull Crusher", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 12),
        .init(id: "db_skull_crusher", name: "Dumbbell Skull Crusher", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 12),
        .init(id: "overhead_tricep_extension", name: "Overhead Tricep Extension", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 12),
        .init(id: "single_arm_oh_extension", name: "Single-Arm Overhead Extension", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "rope_pushdown", name: "Rope Pushdown", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "straight_bar_pushdown", name: "Straight Bar Pushdown", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "v_bar_pushdown", name: "V-Bar Pushdown", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 12),
        .init(id: "reverse_grip_pushdown", name: "Reverse Grip Pushdown", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "overhead_cable_extension", name: "Overhead Cable Extension", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_kickback", name: "Cable Kickback", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "db_kickback", name: "Dumbbell Kickback", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "tricep_dips", name: "Tricep Dips", primaryMuscle: .triceps, secondaryMuscles: [.chest, .shoulders], equipment: .bodyweight, defaultSets: 4, defaultReps: 10),
        .init(id: "bench_dips", name: "Bench Dips", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "diamond_push_up_triceps", name: "Diamond Push-Up (Triceps)", primaryMuscle: .triceps, secondaryMuscles: [.chest], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "plate_press_triceps", name: "Plate Press", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .plate, defaultSets: 3, defaultReps: 15),
        .init(id: "band_pushdown", name: "Band Pushdown", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "band_overhead_extension", name: "Band Overhead Extension", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "machine_tricep_dip", name: "Machine Tricep Dip", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "kettlebell_floor_press", name: "Kettlebell Floor Press", primaryMuscle: .triceps, secondaryMuscles: [.chest], equipment: .kettlebell, defaultSets: 3, defaultReps: 10),
    ]

    // MARK: - Quads

    static let quads: [ExerciseDefinition] = [
        .init(id: "back_squat", name: "Back Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .hamstrings, .core], equipment: .barbell, defaultSets: 4, defaultReps: 6),
        .init(id: "front_squat", name: "Front Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .core], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "goblet_squat", name: "Goblet Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "smith_squat", name: "Smith Machine Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .machine, defaultSets: 4, defaultReps: 8),
        .init(id: "leg_press", name: "Leg Press", primaryMuscle: .quads, secondaryMuscles: [.glutes, .hamstrings], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "hack_squat", name: "Hack Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "leg_extension", name: "Leg Extension", primaryMuscle: .quads, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 12),
        .init(id: "single_leg_extension", name: "Single-Leg Extension", primaryMuscle: .quads, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 12),
        .init(id: "lunge", name: "Walking Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes, .hamstrings], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "static_lunge", name: "Static Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "reverse_lunge", name: "Reverse Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "forward_lunge", name: "Forward Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "lateral_lunge", name: "Lateral Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "curtsy_lunge", name: "Curtsy Lunge", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "split_squat", name: "Split Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "bulgarian_split_squat", name: "Bulgarian Split Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .hamstrings], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "step_up", name: "Step-Up", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "box_squat", name: "Box Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .barbell, defaultSets: 4, defaultReps: 6),
        .init(id: "pause_squat", name: "Pause Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "pistol_squat", name: "Pistol Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .core], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "sissy_squat", name: "Sissy Squat", primaryMuscle: .quads, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "bodyweight_squat", name: "Bodyweight Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "jump_squat", name: "Jump Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "kb_squat", name: "Kettlebell Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "belt_squat", name: "Belt Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .machine, defaultSets: 4, defaultReps: 10),
        .init(id: "landmine_squat", name: "Landmine Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "zercher_squat", name: "Zercher Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .back], equipment: .barbell, defaultSets: 4, defaultReps: 6),
        .init(id: "overhead_squat", name: "Overhead Squat", primaryMuscle: .quads, secondaryMuscles: [.shoulders, .core], equipment: .barbell, defaultSets: 3, defaultReps: 5),
        .init(id: "band_squat", name: "Band Squat", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "wall_sit", name: "Wall Sit", primaryMuscle: .quads, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
    ]

    // MARK: - Hamstrings

    static let hamstrings: [ExerciseDefinition] = [
        .init(id: "romanian_deadlift", name: "Romanian Deadlift", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes, .back], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "rdl_dumbbell", name: "Dumbbell RDL", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "stiff_leg_deadlift", name: "Stiff-Leg Deadlift", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "leg_curl", name: "Lying Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 12),
        .init(id: "seated_leg_curl", name: "Seated Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 12),
        .init(id: "single_leg_curl", name: "Single-Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 12),
        .init(id: "nordic_curl", name: "Nordic Hamstring Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "good_morning", name: "Good Morning", primaryMuscle: .hamstrings, secondaryMuscles: [.back, .glutes], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "cable_leg_curl", name: "Cable Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "db_good_morning", name: "Dumbbell Good Morning", primaryMuscle: .hamstrings, secondaryMuscles: [.back], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "kettlebell_deadlift", name: "Kettlebell Deadlift", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "single_leg_rdl", name: "Single-Leg RDL", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "glute_ham_raise", name: "Glute Ham Raise", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .machine, defaultSets: 3, defaultReps: 10),
        .init(id: "reverse_hyper", name: "Reverse Hyperextension", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes, .back], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "slider_leg_curl", name: "Slider Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "band_leg_curl", name: "Band Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "swiss_ball_curl", name: "Swiss Ball Leg Curl", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
    ]

    // MARK: - Glutes

    static let glutes: [ExerciseDefinition] = [
        .init(id: "hip_thrust", name: "Hip Thrust", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "single_leg_hip_thrust", name: "Single-Leg Hip Thrust", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .barbell, defaultSets: 3, defaultReps: 10),
        .init(id: "db_hip_thrust", name: "Dumbbell Hip Thrust", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 12),
        .init(id: "glute_bridge", name: "Glute Bridge", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "weighted_glute_bridge", name: "Weighted Glute Bridge", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "single_leg_glute_bridge", name: "Single-Leg Glute Bridge", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "cable_pull_through", name: "Cable Pull-Through", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_kickback", name: "Cable Glute Kickback", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "db_kickback_glute", name: "Dumbbell Kickback", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "band_kickback", name: "Band Kickback", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "lateral_band_walk", name: "Lateral Band Walk", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "clam_shell", name: "Clam Shell", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "banded_clam", name: "Banded Clam Shell", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 15),
        .init(id: "hip_abduction_machine", name: "Hip Abduction Machine", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_hip_abduction", name: "Cable Hip Abduction", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "sumo_deadlift_glutes", name: "Sumo Deadlift (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.quads, .back], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "trap_bar_deadlift_glutes", name: "Trap Bar Deadlift (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.quads], equipment: .barbell, defaultSets: 4, defaultReps: 8),
        .init(id: "kb_swing", name: "Kettlebell Swing", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings, .back], equipment: .kettlebell, defaultSets: 4, defaultReps: 15),
        .init(id: "curtsy_lunge_glutes", name: "Curtsy Lunge (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.quads], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "reverse_hyper_glutes", name: "Reverse Hyperextension (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .machine, defaultSets: 3, defaultReps: 15),
        .init(id: "frog_pump", name: "Frog Pumps", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "step_up_glutes", name: "Step-Up (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.quads], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "bulgarian_glutes", name: "Bulgarian Split Squat (Glutes)", primaryMuscle: .glutes, secondaryMuscles: [.quads], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "rdl_glutes", name: "RDL (Glutes Focus)", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .barbell, defaultSets: 4, defaultReps: 10),
    ]

    // MARK: - Core

    static let core: [ExerciseDefinition] = [
        .init(id: "plank", name: "Plank", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "side_plank", name: "Side Plank", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "weighted_plank", name: "Weighted Plank", primaryMuscle: .core, secondaryMuscles: [], equipment: .plate, defaultSets: 3, defaultReps: 1),
        .init(id: "hanging_leg_raise", name: "Hanging Leg Raise", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "hanging_knee_raise", name: "Hanging Knee Raise", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "toes_to_bar", name: "Toes to Bar", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 10),
        .init(id: "crunch", name: "Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "reverse_crunch", name: "Reverse Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "bicycle_crunch", name: "Bicycle Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "oblique_crunch", name: "Oblique Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_crunch", name: "Cable Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .cable, defaultSets: 4, defaultReps: 15),
        .init(id: "cable_wood_chop", name: "Cable Wood Chop", primaryMuscle: .core, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "pallof_press", name: "Pallof Press", primaryMuscle: .core, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 12),
        .init(id: "dead_bug", name: "Dead Bug", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "bird_dog", name: "Bird Dog", primaryMuscle: .core, secondaryMuscles: [.back], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "russian_twist", name: "Russian Twist", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "weighted_russian_twist", name: "Weighted Russian Twist", primaryMuscle: .core, secondaryMuscles: [], equipment: .plate, defaultSets: 3, defaultReps: 15),
        .init(id: "mountain_climber", name: "Mountain Climbers", primaryMuscle: .core, secondaryMuscles: [.shoulders], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "ab_wheel", name: "Ab Wheel Rollout", primaryMuscle: .core, secondaryMuscles: [], equipment: .other, defaultSets: 3, defaultReps: 10),
        .init(id: "hollow_hold", name: "Hollow Body Hold", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "v_up", name: "V-Up", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "leg_raise_floor", name: "Lying Leg Raise", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "scissor_kick", name: "Scissor Kicks", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "flutter_kick", name: "Flutter Kicks", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 20),
        .init(id: "plank_up_down", name: "Plank Up-Downs", primaryMuscle: .core, secondaryMuscles: [.shoulders, .triceps], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "side_bend", name: "Dumbbell Side Bend", primaryMuscle: .core, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "cable_side_bend", name: "Cable Side Bend", primaryMuscle: .core, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "standing_cable_rotation", name: "Standing Cable Rotation", primaryMuscle: .core, secondaryMuscles: [], equipment: .cable, defaultSets: 3, defaultReps: 15),
        .init(id: "dragon_flag", name: "Dragon Flag", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "l_sit", name: "L-Sit", primaryMuscle: .core, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "machine_ab_crunch", name: "Machine Ab Crunch", primaryMuscle: .core, secondaryMuscles: [], equipment: .machine, defaultSets: 3, defaultReps: 15),
    ]

    // MARK: - Calves

    static let calves: [ExerciseDefinition] = [
        .init(id: "standing_calf_raise", name: "Standing Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 15),
        .init(id: "seated_calf_raise", name: "Seated Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 15),
        .init(id: "db_calf_raise", name: "Dumbbell Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 4, defaultReps: 15),
        .init(id: "bb_calf_raise", name: "Barbell Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .barbell, defaultSets: 4, defaultReps: 15),
        .init(id: "single_leg_calf_raise", name: "Single-Leg Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 4, defaultReps: 15),
        .init(id: "bodyweight_calf_raise", name: "Bodyweight Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 4, defaultReps: 20),
        .init(id: "donkey_calf_raise", name: "Donkey Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 4, defaultReps: 15),
        .init(id: "leg_press_calf_raise", name: "Leg Press Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .machine, defaultSets: 4, defaultReps: 15),
        .init(id: "band_calf_raise", name: "Band Calf Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 20),
        .init(id: "tibialis_raise", name: "Tibialis Raise", primaryMuscle: .calves, secondaryMuscles: [], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "jump_rope", name: "Jump Rope", primaryMuscle: .calves, secondaryMuscles: [.shoulders], equipment: .other, defaultSets: 3, defaultReps: 1),
    ]

    // MARK: - Forearms

    static let forearms: [ExerciseDefinition] = [
        .init(id: "wrist_curl", name: "Wrist Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "reverse_wrist_curl", name: "Reverse Wrist Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 15),
        .init(id: "barbell_wrist_curl", name: "Barbell Wrist Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell, defaultSets: 3, defaultReps: 15),
        .init(id: "farmer_walk", name: "Farmer's Walk", primaryMuscle: .biceps, secondaryMuscles: [.core], equipment: .dumbbell, defaultSets: 3, defaultReps: 1),
        .init(id: "plate_pinch", name: "Plate Pinch", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .plate, defaultSets: 3, defaultReps: 1),
        .init(id: "dead_hang", name: "Dead Hang", primaryMuscle: .biceps, secondaryMuscles: [.back], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "towel_pull_up", name: "Towel Pull-Up", primaryMuscle: .biceps, secondaryMuscles: [.back], equipment: .bodyweight, defaultSets: 3, defaultReps: 8),
        .init(id: "fat_grip_curl", name: "Fat Grip Curl", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell, defaultSets: 3, defaultReps: 12),
        .init(id: "band_finger_extension", name: "Band Finger Extension", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .band, defaultSets: 3, defaultReps: 20),
    ]

    // MARK: - Full Body / Compound

    static let fullBody: [ExerciseDefinition] = [
        .init(id: "clean", name: "Power Clean", primaryMuscle: .back, secondaryMuscles: [.quads, .shoulders], equipment: .barbell, defaultSets: 5, defaultReps: 3),
        .init(id: "clean_and_jerk", name: "Clean and Jerk", primaryMuscle: .shoulders, secondaryMuscles: [.quads, .back], equipment: .barbell, defaultSets: 5, defaultReps: 3),
        .init(id: "snatch", name: "Snatch", primaryMuscle: .shoulders, secondaryMuscles: [.back, .quads], equipment: .barbell, defaultSets: 5, defaultReps: 3),
        .init(id: "thruster", name: "Thruster", primaryMuscle: .quads, secondaryMuscles: [.shoulders, .core], equipment: .barbell, defaultSets: 4, defaultReps: 10),
        .init(id: "db_thruster", name: "Dumbbell Thruster", primaryMuscle: .quads, secondaryMuscles: [.shoulders], equipment: .dumbbell, defaultSets: 4, defaultReps: 10),
        .init(id: "turkish_get_up", name: "Turkish Get-Up", primaryMuscle: .core, secondaryMuscles: [.shoulders, .quads], equipment: .kettlebell, defaultSets: 3, defaultReps: 5),
        .init(id: "kb_clean", name: "Kettlebell Clean", primaryMuscle: .back, secondaryMuscles: [.shoulders], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "kb_snatch", name: "Kettlebell Snatch", primaryMuscle: .back, secondaryMuscles: [.shoulders, .glutes], equipment: .kettlebell, defaultSets: 4, defaultReps: 10),
        .init(id: "burpee", name: "Burpee", primaryMuscle: .chest, secondaryMuscles: [.quads, .core], equipment: .bodyweight, defaultSets: 3, defaultReps: 15),
        .init(id: "man_maker", name: "Man Maker", primaryMuscle: .back, secondaryMuscles: [.chest, .shoulders, .quads], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "bear_crawl", name: "Bear Crawl", primaryMuscle: .core, secondaryMuscles: [.shoulders, .quads], equipment: .bodyweight, defaultSets: 3, defaultReps: 1),
        .init(id: "farmer_carry", name: "Farmer's Carry", primaryMuscle: .core, secondaryMuscles: [.back], equipment: .dumbbell, defaultSets: 3, defaultReps: 1),
        .init(id: "sandbag_carry", name: "Sandbag Carry", primaryMuscle: .core, secondaryMuscles: [.back, .quads], equipment: .other, defaultSets: 3, defaultReps: 1),
        .init(id: "wall_ball", name: "Wall Ball", primaryMuscle: .quads, secondaryMuscles: [.shoulders, .core], equipment: .other, defaultSets: 3, defaultReps: 15),
        .init(id: "box_jump", name: "Box Jump", primaryMuscle: .quads, secondaryMuscles: [.glutes, .calves], equipment: .bodyweight, defaultSets: 3, defaultReps: 12),
        .init(id: "db_snatch", name: "Dumbbell Snatch", primaryMuscle: .back, secondaryMuscles: [.shoulders, .glutes], equipment: .dumbbell, defaultSets: 3, defaultReps: 10),
        .init(id: "landmine_full", name: "Landmine Rainbow", primaryMuscle: .core, secondaryMuscles: [.shoulders, .back], equipment: .barbell, defaultSets: 3, defaultReps: 10),
    ]

    // MARK: - Cardio / Conditioning

    static let cardio: [ExerciseDefinition] = [
        .init(id: "rowing_machine", name: "Rowing Machine", primaryMuscle: .back, secondaryMuscles: [.quads, .core], equipment: .machine, defaultSets: 1, defaultReps: 1),
        .init(id: "assault_bike", name: "Assault Bike", primaryMuscle: .quads, secondaryMuscles: [], equipment: .machine, defaultSets: 1, defaultReps: 1),
        .init(id: "treadmill_sprint", name: "Treadmill Sprint", primaryMuscle: .quads, secondaryMuscles: [.hamstrings, .calves], equipment: .machine, defaultSets: 6, defaultReps: 1),
        .init(id: "stationary_bike", name: "Stationary Bike", primaryMuscle: .quads, secondaryMuscles: [], equipment: .machine, defaultSets: 1, defaultReps: 1),
        .init(id: "stair_climber", name: "Stair Climber", primaryMuscle: .quads, secondaryMuscles: [.glutes, .calves], equipment: .machine, defaultSets: 1, defaultReps: 1),
        .init(id: "battle_rope", name: "Battle Ropes", primaryMuscle: .shoulders, secondaryMuscles: [.core], equipment: .other, defaultSets: 4, defaultReps: 1),
        .init(id: "sled_push", name: "Sled Push", primaryMuscle: .quads, secondaryMuscles: [.glutes, .calves], equipment: .other, defaultSets: 4, defaultReps: 1),
        .init(id: "sled_pull", name: "Sled Pull", primaryMuscle: .back, secondaryMuscles: [.biceps, .quads], equipment: .other, defaultSets: 4, defaultReps: 1),
        .init(id: "kb_swing_cardio", name: "Kettlebell Swing (Cardio)", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .kettlebell, defaultSets: 4, defaultReps: 20),
    ]

    // MARK: - Helpers

    /// Exercises grouped by primary muscle group.
    static var groupedByMuscle: [(MuscleGroup, [ExerciseDefinition])] {
        let order: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .calves, .core]
        return order.map { muscle in
            (muscle, all.filter { $0.primaryMuscle == muscle })
        }.filter { !$0.1.isEmpty }
    }

    /// Search exercises by name, filtered by optional muscle and equipment.
    static func search(query: String, muscle: MuscleGroup?, equipment: ExerciseEquipment?) -> [ExerciseDefinition] {
        var results = all
        if let muscle {
            results = results.filter { $0.primaryMuscle == muscle || $0.secondaryMuscles.contains(muscle) }
        }
        if let equipment {
            results = results.filter { $0.equipment == equipment }
        }
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return results }
        return results.filter { $0.name.lowercased().contains(q) }
    }
}


