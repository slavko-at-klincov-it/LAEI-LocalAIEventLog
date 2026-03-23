import Foundation

struct PortProbeResult: Sendable {
    let port: UInt16
    let runtimeType: RuntimeType
    let isResponding: Bool
    let version: String?
    let responseData: Data?
}

struct PortProbe: Sendable {
    let port: UInt16
    let runtime: RuntimeType
    let path: String
    let healthPath: String?
}

actor PortProber {
    private let probes: [PortProbe] = [
        PortProbe(port: 11434, runtime: .ollama, path: "/api/version", healthPath: nil),
        PortProbe(port: 1234, runtime: .lmStudio, path: "/v1/models", healthPath: nil),
        PortProbe(port: 8080, runtime: .llamaCpp, path: "/health", healthPath: nil),
        PortProbe(port: 4891, runtime: .gpt4All, path: "/v1/models", healthPath: nil),
        PortProbe(port: 5001, runtime: .koboldCpp, path: "/api/v1/info/version", healthPath: nil),
        PortProbe(port: 1337, runtime: .jan, path: "/v1/models", healthPath: nil),
        PortProbe(port: 8585, runtime: .localAI, path: "/v1/models", healthPath: nil),
    ]

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2.0
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func probeAll() async -> [PortProbeResult] {
        await withTaskGroup(of: PortProbeResult?.self) { group in
            for probe in probes {
                group.addTask { [session] in
                    await Self.probePort(probe, session: session)
                }
            }

            var results: [PortProbeResult] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results
        }
    }

    func probePort(_ port: UInt16, runtime: RuntimeType, path: String) async -> PortProbeResult? {
        let probe = PortProbe(port: port, runtime: runtime, path: path, healthPath: nil)
        return await Self.probePort(probe, session: session)
    }

    private static func probePort(_ probe: PortProbe, session: URLSession) async -> PortProbeResult? {
        guard let url = URL(string: "http://127.0.0.1:\(probe.port)\(probe.path)") else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }

            var version: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                version = json["version"] as? String
            }

            return PortProbeResult(
                port: probe.port,
                runtimeType: probe.runtime,
                isResponding: true,
                version: version,
                responseData: data
            )
        } catch {
            return nil
        }
    }
}
