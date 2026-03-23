import Foundation

enum RuntimeType: String, Codable, CaseIterable, Identifiable, Sendable {
    case ollama
    case lmStudio
    case llamaCpp
    case gpt4All
    case koboldCpp
    case textGenerationWebUI
    case jan
    case msty
    case mlx
    case llamafile
    case localAI
    case vllm
    case openWebUI
    case anythingLLM
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        case .llamaCpp: "llama.cpp"
        case .gpt4All: "GPT4All"
        case .koboldCpp: "KoboldCpp"
        case .textGenerationWebUI: "Text Gen WebUI"
        case .jan: "Jan"
        case .msty: "Msty"
        case .mlx: "MLX"
        case .llamafile: "Llamafile"
        case .localAI: "LocalAI"
        case .vllm: "vLLM"
        case .openWebUI: "Open WebUI"
        case .anythingLLM: "AnythingLLM"
        case .unknown: "Unknown"
        }
    }

    var iconSystemName: String {
        switch self {
        case .ollama: "server.rack"
        case .lmStudio: "desktopcomputer"
        case .llamaCpp: "terminal"
        case .gpt4All: "bubble.left.and.bubble.right"
        case .koboldCpp: "terminal.fill"
        case .textGenerationWebUI: "globe"
        case .jan: "app.badge"
        case .msty: "sparkles"
        case .mlx: "apple.terminal"
        case .llamafile: "doc.zipper"
        case .localAI: "cpu"
        case .vllm: "bolt.horizontal"
        case .openWebUI: "globe.americas"
        case .anythingLLM: "ellipsis.bubble"
        case .unknown: "questionmark.circle"
        }
    }
}

struct AIRuntime: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let type: RuntimeType
    let processID: Int32
    let processName: String
    var endpoint: URL?
    var version: String?
    var loadedModels: [AIModel]
    var resourceUsage: ResourceUsage
    var detectedAt: Date
    var lastSeen: Date
    var isResponding: Bool

    init(
        id: UUID = UUID(),
        type: RuntimeType,
        processID: Int32,
        processName: String,
        endpoint: URL? = nil,
        version: String? = nil,
        loadedModels: [AIModel] = [],
        resourceUsage: ResourceUsage = .zero,
        detectedAt: Date = .now,
        lastSeen: Date = .now,
        isResponding: Bool = true
    ) {
        self.id = id
        self.type = type
        self.processID = processID
        self.processName = processName
        self.endpoint = endpoint
        self.version = version
        self.loadedModels = loadedModels
        self.resourceUsage = resourceUsage
        self.detectedAt = detectedAt
        self.lastSeen = lastSeen
        self.isResponding = isResponding
    }
}
