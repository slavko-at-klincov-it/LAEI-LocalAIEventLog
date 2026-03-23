import Foundation

actor OllamaModelIdentifier {
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        return URLSession(configuration: config)
    }()

    func identifyModels(port: UInt16 = 11434) async -> [AIModel] {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/ps") else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            let psResponse = try JSONDecoder().decode(OllamaPSResponse.self, from: data)
            return psResponse.models.map { m in
                AIModel(
                    name: m.name,
                    displayName: m.name,
                    parameterCount: m.details?.parameterSize,
                    quantization: m.details?.quantizationLevel,
                    fileSize: m.size,
                    vramSize: m.sizeVram,
                    runtimeType: .ollama,
                    loadedAt: m.expiresAt.flatMap { parseRelativeExpiry($0) }
                )
            }
        } catch {
            return []
        }
    }

    private func parseRelativeExpiry(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
}

// MARK: - Ollama API Response Types

private struct OllamaPSResponse: Codable {
    let models: [OllamaRunningModel]
}

private struct OllamaRunningModel: Codable {
    let name: String
    let model: String?
    let size: Int64?
    let sizeVram: Int64?
    let digest: String?
    let details: OllamaModelDetails?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case name, model, size, digest, details
        case sizeVram = "size_vram"
        case expiresAt = "expires_at"
    }
}

private struct OllamaModelDetails: Codable {
    let parentModel: String?
    let format: String?
    let family: String?
    let families: [String]?
    let parameterSize: String?
    let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case parentModel = "parent_model"
        case format, family, families
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}
