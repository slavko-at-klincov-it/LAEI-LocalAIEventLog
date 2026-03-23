import Foundation

struct ProcessSignature: Sendable {
    let runtime: RuntimeType
    let namePatterns: [String]
    let pathPatterns: [String]
    let argPatterns: [String]
    let defaultPort: UInt16?
}

enum ProcessSignatureDB {
    static let signatures: [ProcessSignature] = [
        ProcessSignature(
            runtime: .ollama,
            namePatterns: ["ollama"],
            pathPatterns: ["Ollama.app", "ollama"],
            argPatterns: ["serve"],
            defaultPort: 11434
        ),
        ProcessSignature(
            runtime: .lmStudio,
            namePatterns: ["LM Studio", "lms", "lmstudio"],
            pathPatterns: ["LM Studio.app", ".lmstudio"],
            argPatterns: ["server"],
            defaultPort: 1234
        ),
        ProcessSignature(
            runtime: .llamaCpp,
            namePatterns: ["llama-server", "llama-cli"],
            pathPatterns: ["llama.cpp", "llama-server"],
            argPatterns: ["--model", "-m"],
            defaultPort: 8080
        ),
        ProcessSignature(
            runtime: .gpt4All,
            namePatterns: ["gpt4all", "chat"],
            pathPatterns: ["GPT4All.app"],
            argPatterns: [],
            defaultPort: 4891
        ),
        ProcessSignature(
            runtime: .koboldCpp,
            namePatterns: ["koboldcpp"],
            pathPatterns: ["koboldcpp"],
            argPatterns: ["--model"],
            defaultPort: 5001
        ),
        ProcessSignature(
            runtime: .textGenerationWebUI,
            namePatterns: ["python", "python3"],
            pathPatterns: [],
            argPatterns: ["text-generation", "server.py"],
            defaultPort: 7860
        ),
        ProcessSignature(
            runtime: .jan,
            namePatterns: ["Jan", "jan"],
            pathPatterns: ["Jan.app"],
            argPatterns: [],
            defaultPort: 1337
        ),
        ProcessSignature(
            runtime: .msty,
            namePatterns: ["Msty"],
            pathPatterns: ["Msty.app"],
            argPatterns: [],
            defaultPort: nil
        ),
        ProcessSignature(
            runtime: .mlx,
            namePatterns: ["python", "python3"],
            pathPatterns: [],
            argPatterns: ["mlx_lm", "mlx.generate", "mlx-community"],
            defaultPort: nil
        ),
        ProcessSignature(
            runtime: .llamafile,
            namePatterns: ["llamafile"],
            pathPatterns: [".llamafile"],
            argPatterns: ["--model"],
            defaultPort: 8080
        ),
        ProcessSignature(
            runtime: .localAI,
            namePatterns: ["local-ai"],
            pathPatterns: ["local-ai"],
            argPatterns: ["--models-path"],
            defaultPort: 8585
        ),
        ProcessSignature(
            runtime: .vllm,
            namePatterns: ["python", "python3"],
            pathPatterns: [],
            argPatterns: ["vllm.entrypoints", "-m vllm"],
            defaultPort: 8000
        ),
        ProcessSignature(
            runtime: .openWebUI,
            namePatterns: ["python", "python3"],
            pathPatterns: [],
            argPatterns: ["open_webui"],
            defaultPort: 3001
        ),
        ProcessSignature(
            runtime: .anythingLLM,
            namePatterns: ["AnythingLLM"],
            pathPatterns: ["AnythingLLM.app"],
            argPatterns: [],
            defaultPort: 3000
        ),
    ]

    static func match(processInfo: ProcessInfo_LP) -> ProcessSignature? {
        let nameLower = processInfo.name.lowercased()
        let pathLower = processInfo.path.lowercased()
        let argsJoined = processInfo.arguments.joined(separator: " ").lowercased()

        // Python processes need arg matching to disambiguate
        let isPython = nameLower.hasPrefix("python")

        for sig in signatures {
            let nameMatch = sig.namePatterns.contains { nameLower.contains($0.lowercased()) }
            let pathMatch = sig.pathPatterns.contains { pathLower.contains($0.lowercased()) }

            if isPython && sig.namePatterns.contains(where: { $0.lowercased().hasPrefix("python") }) {
                // For Python-based tools, require arg pattern match
                let argMatch = sig.argPatterns.contains { argsJoined.contains($0.lowercased()) }
                if argMatch { return sig }
            } else if nameMatch || pathMatch {
                return sig
            }
        }

        return nil
    }
}
