import Foundation

enum CommandLineModelIdentifier {
    static func identifyModels(from arguments: [String], runtimeType: RuntimeType) -> [AIModel] {
        var models: [AIModel] = []

        for i in 0..<arguments.count {
            let arg = arguments[i]

            // Check for --model / -m flags followed by a path
            if (arg == "--model" || arg == "-m"), i + 1 < arguments.count {
                let path = arguments[i + 1]
                if let model = modelFromPath(path, runtimeType: runtimeType) {
                    models.append(model)
                }
            }

            // Check for direct GGUF/bin file references
            if arg.hasSuffix(".gguf") || arg.hasSuffix(".ggml") {
                if let model = modelFromPath(arg, runtimeType: runtimeType) {
                    models.append(model)
                }
            }
        }

        return models
    }

    private static func modelFromPath(_ path: String, runtimeType: RuntimeType) -> AIModel? {
        let filename = (path as NSString).lastPathComponent
        guard !filename.isEmpty else { return nil }

        let nameWithoutExt = filename
            .replacingOccurrences(of: ".gguf", with: "")
            .replacingOccurrences(of: ".ggml", with: "")
            .replacingOccurrences(of: ".bin", with: "")

        // Try to extract quantization from filename (e.g., "model-name.Q4_K_M.gguf")
        let components = nameWithoutExt.components(separatedBy: ".")
        var quantization: String?
        var modelName = nameWithoutExt

        if components.count >= 2 {
            let lastPart = components.last ?? ""
            if lastPart.hasPrefix("Q") || lastPart.hasPrefix("q") || lastPart.contains("_K_") || lastPart.contains("F16") || lastPart.contains("f16") {
                quantization = lastPart
                modelName = components.dropLast().joined(separator: ".")
            }
        }

        return AIModel(
            name: modelName,
            displayName: modelName,
            quantization: quantization,
            runtimeType: runtimeType
        )
    }
}
