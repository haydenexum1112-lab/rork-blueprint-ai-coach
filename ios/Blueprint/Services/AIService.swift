import Foundation

nonisolated enum AIServiceError: LocalizedError {
    case missingConfig
    case imageTooLarge
    case network(String)
    case badStatus(Int)
    case emptyResponse
    case parsing
    case invalidPhotos

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "The AI service isn't configured yet. Please try again later."
        case .imageTooLarge:
            return "One of your photos couldn't be compressed enough to analyze. Try retaking it."
        case .network(let message):
            return "Network issue: \(message). Check your connection and try again."
        case .badStatus(let code):
            return "The analysis service returned an error (\(code)). Please try again."
        case .emptyResponse:
            return "The analysis came back empty. Please try again."
        case .parsing:
            return "We couldn't read the analysis result. Please try again."
        case .invalidPhotos:
            return "These photos don't show a clear full-body physique. Please retake with your whole body visible from head to toe."
        }
    }
}

/// Input bundle for one physique analysis call.
nonisolated struct AnalysisInput {
    let profileContext: String
    let frames: [Data]
    let targets: [(data: Data, caption: String)]
}

/// Calls GPT-4o (vision) through the Rork Toolkit proxy and parses
/// the strict-JSON physique analysis + workout plan.
nonisolated enum AIService {
    static let modelId = "openai/gpt-4o"

    private static let frameByteBudget = 420_000
    private static let targetByteBudget = 250_000

    private static let systemPrompt = """
    You are PhyziqAi, an elite physique coach and exercise scientist. You analyze physique photos and produce honest, encouraging, actionable assessments and hypertrophy-focused training plans.

    STRICT RULES:
    - Assess muscle development, symmetry, and proportions by training level. Be honest but always encouraging and respectful.
    - Lead with strengths. Never shame. Frame gaps as opportunities, not failures.
    - NEVER estimate body-fat percentage as a medical claim. Never mention body-fat numbers.
    - NEVER give crash-diet advice, calorie targets, or weight-loss quotas.
    - If the user's goal physique is unrealistic short-term, do NOT say it's impossible — build the plan toward it sustainably and note the priorities.
    - Respect the user's available equipment, training days, and experience level exactly.
    - Programming must be safe: sensible volume, rest, and exercise selection for the stated experience level.
    - Respond with ONLY a single valid JSON object. No markdown, no code fences, no commentary before or after.

    PHYSIQUE SCORE:
    - Assign an overall physique score from 1-100 reflecting muscle development, symmetry, and proportion FOR THE USER'S TRAINING LEVEL.
    - Score relative to their experience tier — a well-developed beginner can still score high. Do not penalize someone for not being advanced.
    - Break the score down byRegion using these keys: "chest", "shoulders", "back", "arms", "legs", "core".
    - Set confidence to "low" if photos are poorly lit, angled, or partially obscured. "medium" for typical photos. "high" only when all three frames are clear, well-lit, and show the full body sharply.
    - The score is a motivational tracking metric, NOT a clinical or medical-grade measurement. Never claim medical, clinical, or diagnostic accuracy.

    PHOTO VALIDATION — CRITICAL:
    - Each current-physique photo MUST show a clear, full human body (head to feet, torso and limbs visible) in fitness attire or minimal clothing.
    - If ANY current-physique photo is a close-up, selfie, headshot, face-only, non-human, or does not show enough of the body to assess a physique, you MUST REFUSE the analysis.
    - To refuse, return this exact JSON and nothing else: {"photoValidationError": true, "summary": "Your photos don't show a clear full-body physique. Please retake with your whole body visible from head to toe, in fitted clothing, 2-3 meters from the camera.", "assessment": {"strengths": [], "focusAreas": []}, "gapToGoal": [], "plan": {"splitName": "", "daysPerWeek": 0, "days": []}, "physiqueScore": {"overall": 0, "byRegion": {}}, "confidence": "low"}
    - Do NOT guess, invent, or fabricate any assessment when you cannot clearly see the user's body. Returning a confident analysis of a forehead, face, or non-body photo is a critical failure.
    - Only proceed with the full assessment when all three current-physique frames clearly show a human body suitable for physique evaluation.

    OUTPUT SCHEMA (exact keys, no extras at the top level):
    {
      "summary": "2-3 sentence overall assessment, honest and motivating",
      "physiqueScore": {
        "overall": 72,
        "byRegion": {"chest": 70, "shoulders": 78, "back": 65, "arms": 72, "legs": 68, "core": 60}
      },
      "confidence": "medium",
      "assessment": {
        "strengths": ["..."],
        "focusAreas": [{"region": "shoulders", "note": "..."}]
      },
      "gapToGoal": [{"region": "chest", "priority": 1, "rationale": "..."}],
      "plan": {
        "splitName": "Upper/Lower 4-day",
        "daysPerWeek": 4,
        "days": [
          {
            "day": "Day 1 — Upper (Push focus)",
            "targets": ["chest", "shoulders"],
            "exercises": [
              {"name": "Incline Dumbbell Press", "sets": 4, "reps": "8-10", "restSec": 120, "why": "ties to the analysis", "alt": "Machine Incline Press", "cues": ["cue 1", "cue 2"]}
            ]
          }
        ]
      }
    }

    - "gapToGoal" is ranked, priority 1 = highest. 3-5 items.
    - Every exercise "why" must tie back to this user's specific analysis or goal.
    - Include "alt" (an equivalent alternative for the same equipment tier) and 2-3 short form "cues" for every exercise.
    - The number of days must match the user's requested training days.
    - Choose a clear, recognizable split name such as "Push/Pull/Legs 5-day", "Upper/Lower 4-day", or "Full Body 3-day".
    """

    /// Runs the full analysis. Returns the parsed result plus the raw JSON string.
    static func analyze(_ input: AnalysisInput) async throws -> (result: AnalysisResult, rawJSON: String) {
        let toolkitURL = RuntimeConfig.toolkitURL
        let secret = RuntimeConfig.rorkToolkitSecretKey
        guard !toolkitURL.isEmpty, !secret.isEmpty else {
            throw AIServiceError.missingConfig
        }

        var contentParts: [[String: Any]] = []
        contentParts.append([
            "type": "text",
            "text": "USER CONTEXT:\n\(input.profileContext)\n\nBelow are the user's current physique photos in order: FRONT, SIDE, BACK — followed by their goal-physique reference photos.",
        ])

        let poseLabels = ["Current physique — FRONT view:", "Current physique — SIDE view:", "Current physique — BACK view:"]
        for (index, frame) in input.frames.enumerated() {
            guard let resized = ImageResizer.resize(frame, maxBytes: frameByteBudget) else {
                throw AIServiceError.imageTooLarge
            }
            contentParts.append(["type": "text", "text": poseLabels[min(index, poseLabels.count - 1)]])
            contentParts.append(imagePart(resized))
        }

        for (index, target) in input.targets.enumerated() {
            guard let resized = ImageResizer.resize(target.data, maxBytes: targetByteBudget) else {
                continue
            }
            let captionText = target.caption.isEmpty ? "" : " — what they like about it: \(target.caption)"
            contentParts.append(["type": "text", "text": "Goal physique reference \(index + 1)\(captionText):"])
            contentParts.append(imagePart(resized))
        }

        contentParts.append([
            "type": "text",
            "text": "Analyze the current physique against the goal references and produce the JSON exactly per the schema. JSON only.",
        ])

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 8000,
            "temperature": 0.6,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": contentParts],
            ],
        ]

        guard let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw AIServiceError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let startTime = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }
        let elapsed = Date().timeIntervalSince(startTime)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.network("invalid response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            print("[AIService] Bad status \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(400) ?? "")")
            throw AIServiceError.badStatus(http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            print("[AIService] Failed to parse response JSON: \(String(data: data, encoding: .utf8)?.prefix(600) ?? "")")
            if elapsed > 30 {
                throw AIServiceError.network("Analysis timed out after \(Int(elapsed))s")
            }
            throw AIServiceError.emptyResponse
        }

        // Content can be a plain string (OpenAI format) or an array of blocks (Anthropic format)
        let content: String
        if let str = message["content"] as? String, !str.isEmpty {
            content = str
        } else if let blocks = message["content"] as? [[String: Any]] {
            content = blocks.compactMap { $0["text"] as? String }.joined()
        } else {
            print("[AIService] No usable content in message: \(message)")
            throw AIServiceError.emptyResponse
        }

        guard !content.isEmpty else {
            print("[AIService] Content was empty after extraction")
            throw AIServiceError.emptyResponse
        }

        let cleaned = extractJSON(from: content)
        guard let cleanedData = cleaned.data(using: .utf8) else {
            throw AIServiceError.parsing
        }
        // Check for photo-validation refusal from the model.
        if let refusalDict = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
           refusalDict["photoValidationError"] as? Bool == true {
            throw AIServiceError.invalidPhotos
        }

        do {
            let result = try JSONDecoder().decode(AnalysisResult.self, from: cleanedData)
            return (result, cleaned)
        } catch {
            print("[AIService] JSON decode failed: \(error)")
            throw AIServiceError.parsing
        }
    }

    private static func imagePart(_ jpegData: Data) -> [String: Any] {
        [
            "type": "image_url",
            "image_url": ["url": "data:image/jpeg;base64,\(jpegData.base64EncodedString())"],
        ]
    }

    /// Strips markdown fences and grabs the outermost JSON object.
    static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") else {
            return cleaned
        }
        return String(cleaned[start ... end])
    }
}
