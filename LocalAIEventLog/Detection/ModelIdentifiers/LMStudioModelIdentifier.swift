import Foundation

actor LMStudioModelIdentifier {
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        return URLSession(configuration: config)
    }()

    func identifyModels(port: UInt16 = 1234) async -> [AIModel] {
        guard let url = URL(string: "http://127.0.0.1:\(port)/v1/models") else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            return modelsResponse.data.map { m in
                let displayName = m.id.components(separatedBy: "/").last ?? m.id
                return AIModel(
                    name: m.id,
                    displayName: displayName,
                    runtimeType: .lmStudio,
                    loadedAt: Date(timeIntervalSince1970: TimeInterval(m.created ?? 0))
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - OpenAI-Compatible Response

private struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModel]
}

private struct OpenAIModel: Codable {
    let id: String
    let object: String?
    let created: Int?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}
