import Foundation
import Combine

@MainActor
@Observable
final class DetectionEngine {
    private(set) var runtimes: [AIRuntime] = []
    private(set) var appState: AppState = .empty

    private let processScanner = ProcessScanner()
    private let portProber = PortProber()
    private let ollamaIdentifier = OllamaModelIdentifier()
    private let lmStudioIdentifier = LMStudioModelIdentifier()
    private let resourceMonitor = ResourceMonitor()
    private let eventStore: EventStore

    private var scanTimer: Timer?
    private var resourceTimer: Timer?
    private var modelQueryTimer: Timer?
    private var previousPIDs: Set<pid_t> = []
    private var previousModelNames: [pid_t: Set<String>] = [:]

    var onEvent: ((DetectionEvent) -> Void)?

    init(eventStore: EventStore) {
        self.eventStore = eventStore
    }

    func start() {
        // Process scan every 5 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performScan()
            }
        }

        // Resource sampling every 2 seconds
        resourceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.sampleResources()
            }
        }

        // Model identification every 30 seconds
        modelQueryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.identifyModels()
            }
        }

        // Initial scan immediately
        Task {
            await performScan()
            await identifyModels()
        }
    }

    func stop() {
        scanTimer?.invalidate()
        resourceTimer?.invalidate()
        modelQueryTimer?.invalidate()
        scanTimer = nil
        resourceTimer = nil
        modelQueryTimer = nil
    }

    func refresh() async {
        await performScan()
        await identifyModels()
        await sampleResources()
    }

    // MARK: - Core Scan

    private func performScan() async {
        // 1. Process-based detection
        let detectedProcesses = await processScanner.scan()

        // 2. Port-based detection
        let portResults = await portProber.probeAll()

        // 3. Heuristic detection for unidentified processes
        let heuristicMatches = await scanHeuristics(excluding: Set(detectedProcesses.map(\.pid)))

        // 4. Merge results into runtimes
        var newRuntimes: [pid_t: AIRuntime] = [:]

        // From process scanner
        for proc in detectedProcesses {
            let portResult = portResults.first { $0.runtimeType == proc.runtimeType }
            let existing = runtimes.first { $0.processID == proc.pid }

            var runtime = AIRuntime(
                id: existing?.id ?? UUID(),
                type: proc.runtimeType,
                processID: proc.pid,
                processName: proc.processName,
                endpoint: proc.defaultPort.flatMap { URL(string: "http://127.0.0.1:\($0)") },
                version: portResult?.version ?? existing?.version,
                loadedModels: existing?.loadedModels ?? CommandLineModelIdentifier.identifyModels(from: proc.arguments, runtimeType: proc.runtimeType),
                resourceUsage: existing?.resourceUsage ?? .zero,
                detectedAt: existing?.detectedAt ?? .now,
                lastSeen: .now,
                isResponding: portResult?.isResponding ?? (existing?.isResponding ?? true)
            )

            // Merge port-discovered models if we didn't have process detection
            if runtime.loadedModels.isEmpty, portResult != nil {
                runtime.isResponding = true
            }

            newRuntimes[proc.pid] = runtime
        }

        // From port probing (servers detected via port but not matched by process scanner)
        for portResult in portResults {
            if !newRuntimes.values.contains(where: { $0.type == portResult.runtimeType }) {
                let existing = runtimes.first { $0.type == portResult.runtimeType }
                let runtime = AIRuntime(
                    id: existing?.id ?? UUID(),
                    type: portResult.runtimeType,
                    processID: existing?.processID ?? -1,
                    processName: portResult.runtimeType.displayName,
                    endpoint: URL(string: "http://127.0.0.1:\(portResult.port)"),
                    version: portResult.version,
                    loadedModels: existing?.loadedModels ?? [],
                    detectedAt: existing?.detectedAt ?? .now,
                    lastSeen: .now,
                    isResponding: true
                )
                newRuntimes[runtime.processID] = runtime
            }
        }

        // From heuristics
        for match in heuristicMatches {
            let existing = runtimes.first { $0.processID == match.pid }
            let runtime = AIRuntime(
                id: existing?.id ?? UUID(),
                type: .unknown,
                processID: match.pid,
                processName: match.processName,
                loadedModels: existing?.loadedModels ?? [],
                detectedAt: existing?.detectedAt ?? .now,
                lastSeen: .now,
                isResponding: true
            )
            newRuntimes[match.pid] = runtime
        }

        // 5. Diff and emit events
        let currentPIDs = Set(newRuntimes.keys)

        // New runtimes
        for pid in currentPIDs.subtracting(previousPIDs) {
            if let runtime = newRuntimes[pid] {
                let event = DetectionEvent.runtimeAppeared(runtime)
                onEvent?(event)
                eventStore.log(
                    runtimeType: runtime.type,
                    modelName: runtime.loadedModels.first?.name ?? runtime.processName,
                    event: .runtimeStarted,
                    ramBytes: runtime.resourceUsage.residentMemoryBytes,
                    cpu: runtime.resourceUsage.cpuPercent
                )
            }
        }

        // Disappeared runtimes
        for pid in previousPIDs.subtracting(currentPIDs) {
            if let runtime = runtimes.first(where: { $0.processID == pid }) {
                let event = DetectionEvent.runtimeDisappeared(runtime)
                onEvent?(event)
                eventStore.log(
                    runtimeType: runtime.type,
                    modelName: runtime.loadedModels.first?.name ?? runtime.processName,
                    event: .runtimeStopped,
                    ramBytes: 0,
                    cpu: 0
                )
            }
        }

        previousPIDs = currentPIDs
        runtimes = Array(newRuntimes.values).sorted { $0.type.displayName < $1.type.displayName }
        updateAppState()
    }

    private func scanHeuristics(excluding knownPIDs: Set<pid_t>) async -> [HeuristicScore] {
        let allPIDs = LibProcBridge.listAllPIDs()
        var matches: [HeuristicScore] = []

        for pid in allPIDs where !knownPIDs.contains(pid) {
            guard let procInfo = LibProcBridge.getProcessInfo(pid: pid) else { continue }

            // Quick filter: skip very small processes
            if let taskInfo = LibProcBridge.processTaskInfo(pid: pid) {
                let rssMB = Double(taskInfo.ptinfo.pti_resident_size) / 1_048_576
                guard rssMB > 500 else { continue }
            } else {
                continue
            }

            let score = HeuristicDetector.score(processInfo: procInfo)
            if score.score >= HeuristicDetector.probableThreshold {
                matches.append(score)
            }
        }

        return matches
    }

    // MARK: - Resource Sampling

    private func sampleResources() async {
        var activePIDs = Set<pid_t>()

        for i in runtimes.indices {
            let pid = runtimes[i].processID
            activePIDs.insert(pid)
            runtimes[i].resourceUsage = await resourceMonitor.sample(pid: pid)
        }

        await resourceMonitor.cleanup(activePIDs: activePIDs)
        updateAppState()
    }

    // MARK: - Model Identification

    private func identifyModels() async {
        for i in runtimes.indices {
            let runtime = runtimes[i]
            var models: [AIModel] = []

            switch runtime.type {
            case .ollama:
                let port = runtime.endpoint.flatMap { UInt16($0.port ?? 11434) } ?? 11434
                models = await ollamaIdentifier.identifyModels(port: port)
            case .lmStudio:
                let port = runtime.endpoint.flatMap { UInt16($0.port ?? 1234) } ?? 1234
                models = await lmStudioIdentifier.identifyModels(port: port)
            default:
                continue
            }

            if !models.isEmpty {
                let previousNames = Set(runtimes[i].loadedModels.map(\.name))
                let newNames = Set(models.map(\.name))

                // Log new models
                for name in newNames.subtracting(previousNames) {
                    eventStore.log(
                        runtimeType: runtime.type,
                        modelName: name,
                        event: .modelLoaded,
                        ramBytes: runtime.resourceUsage.residentMemoryBytes,
                        cpu: runtime.resourceUsage.cpuPercent
                    )
                }

                // Log removed models
                for name in previousNames.subtracting(newNames) {
                    eventStore.log(
                        runtimeType: runtime.type,
                        modelName: name,
                        event: .modelUnloaded,
                        ramBytes: 0,
                        cpu: 0
                    )
                }

                runtimes[i].loadedModels = models
            }
        }

        updateAppState()
    }

    // MARK: - State

    private func updateAppState() {
        let totalCPU = runtimes.reduce(0.0) { $0 + $1.resourceUsage.cpuPercent }
        let totalRAM = runtimes.reduce(UInt64(0)) { $0 + $1.resourceUsage.residentMemoryBytes }
        let modelCount = runtimes.reduce(0) { $0 + $1.loadedModels.count }

        appState = AppState(
            runtimes: runtimes,
            totalCPU: totalCPU,
            totalRAMBytes: totalRAM,
            anyActive: !runtimes.isEmpty,
            activeModelCount: modelCount,
            systemAvailableMemoryBytes: 0,
            systemTotalMemoryBytes: SysctlBridge.systemMemorySize(),
            lastUpdated: .now
        )

        // Update system memory async
        Task {
            let available = await resourceMonitor.systemAvailableMemory()
            appState.systemAvailableMemoryBytes = available
        }
    }
}

// MARK: - Detection Events

enum DetectionEvent {
    case runtimeAppeared(AIRuntime)
    case runtimeDisappeared(AIRuntime)
    case modelLoaded(AIRuntime, AIModel)
    case modelUnloaded(AIRuntime, AIModel)
}
