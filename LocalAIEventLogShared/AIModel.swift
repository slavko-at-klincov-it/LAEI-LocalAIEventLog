import Foundation

struct AIModel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    var displayName: String
    var parameterCount: String?
    var quantization: String?
    var contextLength: Int?
    var fileSize: Int64?
    var vramSize: Int64?
    var runtimeType: RuntimeType
    var loadedAt: Date?
    var resourceUsage: ResourceUsage?

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String? = nil,
        parameterCount: String? = nil,
        quantization: String? = nil,
        contextLength: Int? = nil,
        fileSize: Int64? = nil,
        vramSize: Int64? = nil,
        runtimeType: RuntimeType = .unknown,
        loadedAt: Date? = nil,
        resourceUsage: ResourceUsage? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.contextLength = contextLength
        self.fileSize = fileSize
        self.vramSize = vramSize
        self.runtimeType = runtimeType
        self.loadedAt = loadedAt
        self.resourceUsage = resourceUsage
    }
}
