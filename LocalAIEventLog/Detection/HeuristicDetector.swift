import Foundation

struct HeuristicScore: Sendable {
    let pid: pid_t
    let processName: String
    let processPath: String
    let score: Int
    let reasons: [String]
}

enum HeuristicDetector {
    static func score(processInfo: ProcessInfo_LP) -> HeuristicScore {
        var score = 0
        var reasons: [String] = []

        let argsJoined = processInfo.arguments.joined(separator: " ").lowercased()
        let pathLower = processInfo.path.lowercased()

        // Check command-line args for AI-related patterns
        let aiArgPatterns = [
            ("--model", 20), (".gguf", 40), (".safetensors", 30),
            ("transformers", 35), ("torch", 25), ("mlx", 35),
            ("llama", 30), ("inference", 20), ("--n-gpu-layers", 40),
            ("--ctx-size", 30), ("generate", 10), ("chat", 10),
        ]
        for (pattern, points) in aiArgPatterns {
            if argsJoined.contains(pattern) {
                score += points
                reasons.append("arg contains '\(pattern)' (+\(points))")
            }
        }

        // Check path for AI-related patterns
        let aiPathPatterns = [
            ("llm", 15), ("inference", 15), ("model", 10), ("gguf", 40),
        ]
        for (pattern, points) in aiPathPatterns {
            if pathLower.contains(pattern) {
                score += points
                reasons.append("path contains '\(pattern)' (+\(points))")
            }
        }

        // Check for high memory usage (>2GB resident) — indicates large model loaded
        if let taskInfo = LibProcBridge.processTaskInfo(pid: processInfo.pid) {
            let rssGB = Double(taskInfo.ptinfo.pti_resident_size) / 1_073_741_824
            if rssGB > 2.0 {
                score += 15
                reasons.append("high RSS \(String(format: "%.1f", rssGB))GB (+15)")
            }
            if rssGB > 6.0 {
                score += 10
                reasons.append("very high RSS (+10)")
            }
        }

        return HeuristicScore(
            pid: processInfo.pid,
            processName: processInfo.name,
            processPath: processInfo.path,
            score: score,
            reasons: reasons
        )
    }

    static let probableThreshold = 40
    static let confidentThreshold = 60
}
