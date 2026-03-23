import XCTest
@testable import LocalAIEventLog

final class LocalAIEventLogTests: XCTestCase {
    func testProcessSignatureDBMatchesOllama() {
        let procInfo = ProcessInfo_LP(
            pid: 1234,
            name: "ollama",
            path: "/usr/local/bin/ollama",
            arguments: ["ollama", "serve"]
        )
        let match = ProcessSignatureDB.match(processInfo: procInfo)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.runtime, .ollama)
    }

    func testProcessSignatureDBMatchesLMStudio() {
        let procInfo = ProcessInfo_LP(
            pid: 5678,
            name: "LM Studio",
            path: "/Applications/LM Studio.app/Contents/MacOS/LM Studio",
            arguments: ["LM Studio"]
        )
        let match = ProcessSignatureDB.match(processInfo: procInfo)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.runtime, .lmStudio)
    }

    func testProcessSignatureDBDoesNotMatchUnrelated() {
        let procInfo = ProcessInfo_LP(
            pid: 9999,
            name: "Safari",
            path: "/Applications/Safari.app/Contents/MacOS/Safari",
            arguments: ["Safari"]
        )
        let match = ProcessSignatureDB.match(processInfo: procInfo)
        XCTAssertNil(match)
    }

    func testCommandLineModelIdentifier() {
        let args = ["llama-server", "--model", "/path/to/mistral-7b-instruct.Q4_K_M.gguf", "--port", "8080"]
        let models = CommandLineModelIdentifier.identifyModels(from: args, runtimeType: .llamaCpp)
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.name, "mistral-7b-instruct")
        XCTAssertEqual(models.first?.quantization, "Q4_K_M")
    }

    func testHeuristicDetectorScoring() {
        let procInfo = ProcessInfo_LP(
            pid: 1111,
            name: "python3",
            path: "/usr/bin/python3",
            arguments: ["python3", "-m", "mlx_lm", "--model", "mistral-7b.gguf"]
        )
        let score = HeuristicDetector.score(processInfo: procInfo)
        XCTAssertGreaterThanOrEqual(score.score, HeuristicDetector.probableThreshold)
    }

    func testAppStateEmpty() {
        let state = AppState.empty
        XCTAssertFalse(state.anyActive)
        XCTAssertEqual(state.activeModelCount, 0)
        XCTAssertEqual(state.totalCPU, 0)
    }

    func testResourceUsageFormatting() {
        let usage = ResourceUsage(
            cpuPercent: 25.5,
            residentMemoryBytes: 4_294_967_296, // 4 GB
            virtualMemoryBytes: 8_589_934_592,
            gpuMemoryBytes: nil,
            threadCount: 12,
            timestamp: .now
        )
        XCTAssertEqual(usage.residentMemoryGB, 4.0, accuracy: 0.01)
        XCTAssertEqual(usage.residentMemoryMB, 4096.0, accuracy: 0.1)
    }

    func testLAEIFormattersMemory() {
        XCTAssertEqual(LAEIFormatters.memoryString(bytes: UInt64(1_073_741_824)), "1.0 GB")
        XCTAssertEqual(LAEIFormatters.memoryString(bytes: UInt64(536_870_912)), "512 MB")
        XCTAssertEqual(LAEIFormatters.memoryString(bytes: UInt64(4_294_967_296)), "4.0 GB")
    }
}
