# LAEI — Architecture & Technical Documentation

This document describes the full architecture of LAEI (Local AI Event Log), including all design decisions, what alternatives were considered, and why specific choices were made.

---

## Table of Contents

1. [High-Level Architecture](#1-high-level-architecture)
2. [Technology Choices & Rationale](#2-technology-choices--rationale)
3. [Project Structure](#3-project-structure)
4. [Detection Engine](#4-detection-engine)
5. [Model Identification](#5-model-identification)
6. [Resource Monitoring](#6-resource-monitoring)
7. [Data Models](#7-data-models)
8. [Persistence Layer](#8-persistence-layer)
9. [UI Architecture](#9-ui-architecture)
10. [Widget Architecture](#10-widget-architecture)
11. [Data Flow](#11-data-flow)
12. [Notifications & Alerts](#12-notifications--alerts)
13. [Concurrency Model](#13-concurrency-model)
14. [Security & Sandboxing](#14-security--sandboxing)
15. [Performance Budget](#15-performance-budget)
16. [Decisions Log](#16-decisions-log)

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     macOS System                            │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────────┐ │
│  │ Ollama       │  │ LM Studio  │  │ llama.cpp / MLX /   │ │
│  │ (port 11434) │  │ (port 1234)│  │ other AI runtimes   │ │
│  └──────┬───────┘  └─────┬──────┘  └──────────┬──────────┘ │
│         │                │                     │            │
│  ═══════╪════════════════╪═════════════════════╪══════════  │
│         │                │                     │            │
│  ┌──────┴────────────────┴─────────────────────┴──────────┐ │
│  │                  LAEI Application                      │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │              Detection Engine                    │  │ │
│  │  │  ┌─────────────┐ ┌──────────┐ ┌──────────────┐  │  │ │
│  │  │  │  Process     │ │  Port    │ │  Heuristic   │  │  │ │
│  │  │  │  Scanner     │ │  Prober  │ │  Detector    │  │  │ │
│  │  │  └──────┬──────┘ └────┬─────┘ └──────┬───────┘  │  │ │
│  │  │         └─────────────┼──────────────┘           │  │ │
│  │  │                       ▼                          │  │ │
│  │  │              Merge & Dedup                       │  │ │
│  │  │                       │                          │  │ │
│  │  │         ┌─────────────┼──────────────┐           │  │ │
│  │  │         ▼             ▼              ▼           │  │ │
│  │  │  Model Identifiers  Resource    Event Diffing   │  │ │
│  │  │  (Ollama/LM/CLI)   Monitor    (appear/disappear)│  │ │
│  │  └──────────────────────┬───────────────────────────┘  │ │
│  │                         │                              │ │
│  │                         ▼                              │ │
│  │              ┌─────────────────────┐                   │ │
│  │              │  AppState (truth)   │                   │ │
│  │              └─────────┬───────────┘                   │ │
│  │                        │                               │ │
│  │         ┌──────────────┼──────────────────┐            │ │
│  │         ▼              ▼                  ▼            │ │
│  │  ┌─────────────┐ ┌──────────┐  ┌──────────────────┐   │ │
│  │  │  Menu Bar   │ │  Main    │  │  Widget (via     │   │ │
│  │  │  Popover    │ │  Window  │  │  App Group)      │   │ │
│  │  └─────────────┘ └──────────┘  └──────────────────┘   │ │
│  │         │              │                  │            │ │
│  │         ▼              ▼                  │            │ │
│  │  ┌─────────────┐ ┌──────────┐             │            │ │
│  │  │  Alert      │ │ SwiftData│             │            │ │
│  │  │  Manager    │ │ EventLog │             │            │ │
│  │  └─────────────┘ └──────────┘             │            │ │
│  └────────────────────────────────────────────┘            │ │
│                                                            │ │
│  ┌────────────────────────────────────────────┐            │ │
│  │        Widget Extension Process            │            │ │
│  │  ┌──────────────────────────────────────┐  │            │ │
│  │  │ SharedStateReader → WidgetKit Views  │◄─┘            │ │
│  │  └──────────────────────────────────────┘               │ │
│  └────────────────────────────────────────────┘            │ │
└─────────────────────────────────────────────────────────────┘
```

LAEI is a single macOS application with two processes:
1. **Main app process** — Runs the detection engine, UI, persistence, and alerts
2. **Widget extension process** — Reads shared state from the App Group and renders WidgetKit views

---

## 2. Technology Choices & Rationale

### Language: Swift 6 (Strict Concurrency)

**Chosen:** Swift 6 with `SWIFT_STRICT_CONCURRENCY=complete`

**Why:** The detection engine is inherently concurrent — it polls processes, probes HTTP ports, and samples resources on different cadences. Swift 6's strict concurrency checking catches data races at compile time. The `actor` model is a natural fit for isolated system bridge code.

**Considered & rejected:**
- **Objective-C** — No structured concurrency, manual memory management, no benefit for this use case since all macOS APIs we need have Swift equivalents
- **Swift 5 with minimal concurrency** — Would compile, but we'd lose compile-time race detection for the polling engine, which is the most bug-prone part

### UI Framework: SwiftUI

**Chosen:** SwiftUI for all three UI surfaces (main window, menu bar, widget)

**Why:**
- WidgetKit *requires* SwiftUI — there is no AppKit alternative for widgets
- `MenuBarExtra` is a SwiftUI-only API (introduced macOS 13)
- Using one framework across all surfaces means shared view components (`ResourceBar`, `StatusIndicator`) work everywhere
- SwiftUI's `@Observable` macro provides fine-grained view invalidation, important since state updates every 2–5 seconds

**Considered & rejected:**
- **AppKit for main window + SwiftUI for widget** — Would require maintaining two view layers for the same data. Extra complexity with no benefit, since SwiftUI on macOS 14 is mature enough for this type of utility app
- **Electron / web-based UI** — Defeats the purpose of a lightweight system monitor. Electron itself would consume more RAM than many of the AI models we're monitoring

### Observation: `@Observable` (not `ObservableObject`)

**Chosen:** The Observation framework (`@Observable` macro, macOS 14+)

**Why:** `@Observable` provides property-level observation granularity. With `ObservableObject` + `@Published`, any property change invalidates all views observing the object. Since our `DetectionEngine` updates resource snapshots every 2 seconds, the old model would cause unnecessary redraws in views that only care about the runtime list (which changes rarely). `@Observable` only invalidates views that read the specific property that changed.

**Considered & rejected:**
- **`ObservableObject` with `@Published`** — Would work but causes excessive view invalidation. On a 2-second resource polling interval, the dashboard gauges would force sidebar redraws even though the runtime list hasn't changed

### Persistence: SwiftData

**Chosen:** SwiftData (built on SQLite, ships with macOS 14)

**Why:**
- Zero external dependencies — SwiftData ships with the OS
- Native SwiftUI integration via `@Query` property wrapper
- Automatic schema management and lightweight migration
- The activity log is a simple append-only event stream — no complex queries or relationships needed

**Considered & rejected:**
- **Raw SQLite via `sqlite3` C API** — More control but requires manual schema management, SQL string construction, and thread safety. Overkill for an event log
- **Core Data** — SwiftData is its successor with a simpler API. No reason to use the older framework for a greenfield project
- **GRDB / SQLite.swift** — Good libraries but adds an external dependency for something the OS provides natively
- **JSON file on disk** — No querying capability, no partial reads, grows without bound. Unacceptable for a log that could accumulate thousands of entries
- **UserDefaults** — Not designed for large datasets. No query support

### Project Generation: XcodeGen

**Chosen:** XcodeGen with `project.yml`

**Why:** The `.pbxproj` file format is famously merge-hostile and impossible to author by hand. XcodeGen lets us define the project structure declaratively in YAML. The generated `.xcodeproj` is not checked into git — it's regenerated from `project.yml` at build time.

**Considered & rejected:**
- **Swift Package Manager (SPM)** — Cannot create WidgetKit extensions, menu bar apps, or configure entitlements. SPM is for libraries, not app bundles with multiple targets
- **Tuist** — More powerful than XcodeGen but heavier. Requires its own CLI installation and project conventions. Overkill for a 3-target project
- **Manual .xcodeproj** — The pbxproj format is a proprietary plist with UUIDs. Creating it by hand is error-prone and unmaintainable

### Minimum Deployment Target: macOS 14 (Sonoma)

**Why:**
- SwiftData requires macOS 14
- `@Observable` macro requires macOS 14
- WidgetKit on macOS requires macOS 14
- `MenuBarExtra` requires macOS 13 (covered by 14)
- `SMAppService` for launch-at-login requires macOS 13 (covered by 14)
- All Apple Silicon Macs can run macOS 14

**Considered & rejected:**
- **macOS 13 (Ventura)** — Would lose SwiftData and `@Observable`, requiring fallback to Core Data and `ObservableObject`
- **macOS 15 (Sequoia)** — Unnecessarily restrictive; no APIs we need are 15-only

### External Dependencies: None

**Why:** Every capability LAEI needs is available in system frameworks:

| Need | System Framework |
|------|-----------------|
| HTTP requests | `URLSession` |
| Process monitoring | `libproc.h` (Darwin) |
| Memory stats | `mach/mach_host.h` (Darwin) |
| Persistence | SwiftData |
| Notifications | `UserNotifications` |
| Menu bar | SwiftUI `MenuBarExtra` |
| Widgets | WidgetKit |
| Launch at login | `ServiceManagement` |

Zero dependencies means:
- No supply chain risk
- No version conflicts
- No build tool requirements beyond Xcode
- Faster builds
- Smaller binary

**Considered & rejected:**
- **Alamofire** — `URLSession` is sufficient for simple `GET` requests to localhost
- **KeyboardShortcuts (Sindre Sorhus)** — Would be nice for a global hotkey, but deferred to v2 to keep v1 dependency-free
- **Charts (Swift Charts)** — Considered for a timeline view but deferred to v2

---

## 3. Project Structure

### Three Xcode Targets

| Target | Type | Purpose |
|--------|------|---------|
| `LocalAIEventLog` | macOS Application | Main app with detection engine, UI, persistence |
| `LocalAIEventLogWidget` | App Extension (WidgetKit) | Desktop widget showing active models |
| `LocalAIEventLogTests` | Unit Test Bundle | Tests for detection logic, model parsing, formatters |

### Why Three Targets (Not Two)

The widget extension runs in a **separate process** from the main app. It cannot access the main app's memory, singletons, or actors. This is an OS-level constraint, not a design choice. The shared code (`LocalAIEventLogShared/`) is compiled into both targets independently.

**Considered & rejected:**
- **Single target with conditional compilation** — Not possible. WidgetKit extensions must be separate targets with their own `@main` entry point and bundle ID
- **Separate framework target for shared code** — Adds complexity (framework embedding, versioning) for no benefit. Compiling shared source files into both targets is simpler and produces the same result

### Source Organization

```
LocalAIEventLog/           # Main app sources
├── App/                   # Entry point + config
├── Models/                # App-only models (EventRecord)
├── Detection/             # Core detection engine
│   ├── SystemBridge/      # C API wrappers (isolated unsafe code)
│   ├── ModelIdentifiers/  # Per-runtime model querying
│   └── *.swift            # Detectors + coordinator
├── Monitoring/            # Resource + alert management
├── Persistence/           # SwiftData store
├── Views/                 # SwiftUI views
│   ├── MenuBar/           # Menu bar icon + popover
│   ├── MainWindow/        # Full window views
│   └── Shared/            # Reusable components
├── Services/              # Widget state writer
└── Utilities/             # Formatters

LocalAIEventLogShared/     # Compiled into BOTH targets
├── AIRuntime.swift        # RuntimeType enum + struct
├── AIModel.swift          # Model metadata struct
├── ResourceUsage.swift    # Resource snapshot struct
├── AppState.swift         # Aggregate state (Codable)
├── AppGroupConstants.swift
└── SharedStateReader.swift

LocalAIEventLogWidget/     # Widget extension sources
├── LAEIWidget.swift       # Widget bundle + configuration
├── TimelineProvider.swift # Data pipeline
└── *WidgetView.swift      # Size-specific views
```

**Design principle:** Shared types are placed in `LocalAIEventLogShared/` if and only if the widget needs them. The widget needs `AppState`, `AIRuntime`, `AIModel`, `ResourceUsage`, and the App Group constants. Everything else (detection, persistence, alerts) lives in the main app target only.

---

## 4. Detection Engine

### Architecture

The `DetectionEngine` is the central coordinator. It's an `@Observable` `@MainActor` class that orchestrates three detection strategies and publishes results as `@Observable` properties for SwiftUI binding.

```
DetectionEngine (@MainActor, @Observable)
├── ProcessScanner (actor) — scans every 5s
├── PortProber (actor) — probes every 5s
├── HeuristicDetector (enum, stateless) — runs every 5s
├── OllamaModelIdentifier (actor) — queries every 30s
├── LMStudioModelIdentifier (actor) — queries every 30s
├── ResourceMonitor (actor) — samples every 2s
└── EventStore (@MainActor) — persists events
```

### Strategy 1: Process Scanner

**File:** `Detection/ProcessScanner.swift`

Uses macOS `libproc` APIs to enumerate all running processes and match them against known signatures.

**How it works:**
1. `proc_listallpids()` — Returns all PIDs on the system (~400–600 typically). Single syscall, <1ms.
2. For each PID, `proc_name()` and `proc_pidpath()` — Gets the short name and full executable path. ~5ms for 500 PIDs.
3. Match against `ProcessSignatureDB` — A table of known AI runtime signatures.
4. For matches, `sysctl(KERN_PROCARGS2)` — Retrieves full command-line arguments. Only called for matched processes (~0.1ms each).

**Why this approach:**
- `libproc` is the lowest-overhead way to enumerate processes on macOS
- Two-phase filtering (name/path first, then args) keeps the hot path fast
- No shell commands (`ps`, `pgrep`) — those fork a subprocess each time, which is 10–100x slower

**Considered & rejected:**
- **`NSWorkspace.runningApplications`** — Only returns GUI apps with bundle IDs. Misses all CLI tools (ollama, llama-server, python scripts)
- **`NSRunningApplication`** — Same limitation
- **Endpoint Security framework (`es_subscribe`)** — Provides push notifications for process creation/termination, but requires a System Extension (kernel-level), a special Apple entitlement, and MDM deployment. Completely impractical for a user-facing app. Would be ideal if Apple made it accessible
- **Parsing `ps aux` output** — Forks a subprocess, pipes stdout, parses text. Works but is 50x slower than direct `libproc` calls and fragile (locale-dependent output formatting)
- **`/proc` filesystem** — Does not exist on macOS (Linux only)
- **kqueue `EVFILT_PROC`** — Can watch individual PIDs for exit, but cannot discover new processes. Would need to be combined with polling anyway

### Strategy 2: Port Prober

**File:** `Detection/PortProber.swift`

Sends HTTP `GET` requests to known AI runtime ports on `127.0.0.1`.

**Known ports probed:**

| Port | Runtime | Probe Path | Expected Response |
|------|---------|-----------|-------------------|
| 11434 | Ollama | `/api/version` | JSON `{"version":"..."}` |
| 1234 | LM Studio | `/v1/models` | OpenAI-compatible JSON |
| 8080 | llama.cpp | `/health` | `{"status":"ok"}` |
| 4891 | GPT4All | `/v1/models` | OpenAI-compatible JSON |
| 5001 | KoboldCpp | `/api/v1/info/version` | JSON |
| 1337 | Jan | `/v1/models` | OpenAI-compatible JSON |
| 8585 | LocalAI | `/v1/models` | OpenAI-compatible JSON |

**Implementation details:**
- All probes run concurrently via `TaskGroup`
- 0.5s connect timeout, 1.5s total timeout — unreachable ports fail fast
- `URLSessionConfiguration.ephemeral` — No caching, no cookies, no disk writes
- Only `GET` requests — Never sends data to the AI runtimes
- Only probes `127.0.0.1` — Never scans the network

**Why port probing in addition to process scanning:**
- Some runtimes may be running in Docker containers (not visible as native processes)
- Process scanning might miss runtimes with unexpected binary names
- Port probing confirms the runtime is actually serving (not just a zombie process)
- Port probing retrieves version information from the response

**Considered & rejected:**
- **`lsof -i -P`** — Lists all network connections but requires forking a subprocess and parsing text output. Slow and fragile
- **`netstat` parsing** — Same issues as `lsof`
- **Scanning all ports (1–65535)** — Way too slow and noisy. Would take minutes and trigger security software
- **mDNS/Bonjour discovery** — AI runtimes don't advertise themselves via Bonjour
- **`NWBrowser` (Network framework)** — Only discovers Bonjour/mDNS services

### Strategy 3: Heuristic Detector

**File:** `Detection/HeuristicDetector.swift`

A scoring engine for processes not matched by the first two strategies. This catches new/unknown AI tools.

**How it works:**

For each unidentified process with >500MB RSS, it checks multiple signals and assigns points:

| Signal | Points | Rationale |
|--------|--------|-----------|
| Command-line args contain `.gguf` | +40 | GGUF is the dominant model format for local inference |
| Args contain `--model` or `-m` | +20 | Common flag for model loading |
| Args contain `transformers`, `torch`, `mlx` | +25–35 | Python ML libraries |
| Args contain `--n-gpu-layers`, `--ctx-size` | +30–40 | llama.cpp-specific flags |
| Path contains `llm`, `inference`, `gguf` | +10–40 | AI-related binary names |
| RSS > 2 GB | +15 | Large language models require multi-GB memory |
| RSS > 6 GB | +10 additional | Very likely an AI workload |

**Thresholds:**
- Score >= 40 → "probable" AI workload
- Score >= 60 → "confident" AI workload

**Why a scoring system instead of hard rules:**
- No single signal is definitive (a Python process importing `torch` might be training, not serving)
- Multiple weak signals combine into a strong signal
- Easy to tune — adjust point values based on real-world false positive rates
- Extensible — add new signals without rewriting logic

**Considered & rejected:**
- **Machine learning classifier** — Overkill. The signal space is small enough that a weighted score works perfectly
- **Open file inspection (checking for loaded `.gguf` files)** — Planned for v2. Requires iterating file descriptors via `proc_pidinfo(PROC_PIDLISTFDS)` which is more expensive. Deferred to keep v1 simple
- **Metal/GPU usage detection (checking for loaded Metal libraries)** — Also planned for v2. Requires inspecting memory-mapped regions or file descriptors for `com.apple.metal` paths

### Deduplication

When multiple strategies detect the same runtime, the engine deduplicates by PID. Process scanner results take priority (they have the most metadata), enriched with port prober data (version, responding status) and heuristic scores.

---

## 5. Model Identification

Each runtime has its own model identification strategy because there is no universal API.

### Ollama (`OllamaModelIdentifier`)

**Endpoint:** `GET http://127.0.0.1:{port}/api/ps`

Returns the richest metadata of any runtime:
- Model name (e.g., `llama3.1:8b`)
- Parameter size (e.g., `8.0B`)
- Quantization level (e.g., `Q4_0`)
- File size (bytes)
- VRAM usage (bytes)
- Model family
- Expiry time

This is the gold standard — all other identifiers provide less information.

### LM Studio (`LMStudioModelIdentifier`)

**Endpoint:** `GET http://127.0.0.1:{port}/v1/models`

Returns an OpenAI-compatible model list. The model ID typically contains the HuggingFace repository path (e.g., `lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF`), from which we extract a human-readable display name.

Less metadata than Ollama — no parameter count, quantization, or VRAM data from the API.

### Command-Line Parsing (`CommandLineModelIdentifier`)

For runtimes without HTTP APIs (bare llama.cpp, koboldcpp, llamafile, MLX scripts):

1. Scan command-line arguments for `--model` / `-m` flags
2. Extract the file path
3. Parse the filename for model name and quantization level

**Filename parsing example:**
```
mistral-7b-instruct-v0.2.Q4_K_M.gguf
          ↓ split on "."
["mistral-7b-instruct-v0", "2", "Q4_K_M", "gguf"]
          ↓ detect quantization pattern (starts with Q, contains _K_)
name: "mistral-7b-instruct-v0.2"
quant: "Q4_K_M"
```

**Limitation:** If the model file is renamed or in a non-standard location, the name may be cryptic. This is inherent to command-line tools that don't provide an API.

### Query Frequency: 30 Seconds

Model identification uses HTTP API calls, which are heavier than process scanning. Running them every 5 seconds would generate unnecessary network traffic and load on the AI runtimes. 30 seconds is frequent enough to catch model loads/unloads promptly while being respectful of the runtime's resources.

---

## 6. Resource Monitoring

### Per-Process Monitoring (`ResourceMonitor`)

**File:** `Monitoring/ResourceMonitor.swift`

Uses `proc_pidinfo(PROC_PIDTASKALLINFO)` to get `proc_taskallinfo`, which contains both BSD process info and Mach task info in a single syscall.

**CPU percentage calculation:**
1. Read `pti_total_user + pti_total_system` (cumulative CPU time in nanoseconds)
2. Compare with previous sample (stored per-PID)
3. CPU% = (delta_cpu_time / delta_wall_time / core_count) * 100

This is the same method used by `top` and Activity Monitor.

**Memory:**
- `pti_resident_size` — Physical RAM currently used (RSS)
- `pti_virtual_size` — Virtual address space (much larger than RSS, less useful)
- `pti_threadnum` — Number of active threads

### System-Wide Memory

Uses `host_statistics64(HOST_VM_INFO64)` to get VM statistics, then computes available memory as `free_count + inactive_count` pages.

**Considered & rejected:**
- **`os_proc_available_memory()`** — This is the best API for this purpose on iOS, but it is **unavailable on macOS**. We use `host_statistics64` instead, which provides equivalent data
- **`sysctl("hw.memsize")` alone** — Only gives total physical memory, not current availability
- **Parsing `vm_stat` output** — Same data as `host_statistics64` but requires forking a subprocess

### GPU/Metal Monitoring

**Current status:** Not implemented in v1.

**Why deferred:**
- macOS has no public per-process GPU utilization API
- The only per-process approach is inspecting open file descriptors for Metal cache files (which indicates Metal is *loaded*, not how much it's *using*)
- System-wide GPU utilization is available via IOKit (`IOGPUDevice` → `PerformanceStatistics`), but it's not attributable to individual processes
- On Apple Silicon, GPU memory = system memory (unified architecture), so RAM monitoring already captures the memory impact

**Planned for v2:**
- IOKit `PerformanceStatistics` for system-wide GPU utilization percentage
- Open file descriptor inspection for Metal cache files (per-process Metal activity flag)

---

## 7. Data Models

### Shared Types (in `LocalAIEventLogShared/`)

These types are compiled into both the main app and widget extension.

**`RuntimeType` enum** — Enumerates all known AI runtimes (14 cases + `.unknown`). Each case provides a `displayName` and `iconSystemName` for consistent UI rendering across all surfaces.

**`AIRuntime` struct** — Represents a detected runtime instance:
- Identity: `id` (UUID), `processID` (pid_t), `processName`, `endpoint` (URL)
- State: `isResponding`, `version`, `lastSeen`
- Children: `loadedModels: [AIModel]`
- Resources: `resourceUsage: ResourceUsage`

**`AIModel` struct** — Represents a loaded model within a runtime:
- Identity: `id` (UUID), `name`, `displayName`
- Metadata: `parameterCount`, `quantization`, `contextLength`, `fileSize`, `vramSize`
- Association: `runtimeType`

**`ResourceUsage` struct** — A point-in-time resource snapshot:
- `cpuPercent`, `residentMemoryBytes`, `virtualMemoryBytes`, `gpuMemoryBytes`, `threadCount`, `timestamp`
- Computed properties: `residentMemoryMB`, `residentMemoryGB`, `gpuMemoryMB`

**`AppState` struct** — Aggregate snapshot of the entire system, serialized to the App Group for the widget:
- `runtimes: [AIRuntime]` — Full runtime tree
- `totalCPU`, `totalRAMBytes` — Aggregates
- `systemAvailableMemoryBytes`, `systemTotalMemoryBytes` — For pressure calculation
- `anyActive`, `activeModelCount` — Convenience booleans

All shared types conform to `Codable`, `Hashable`, `Sendable`, and `Identifiable`.

### App-Only Types

**`EventRecord` (@Model)** — SwiftData entity for the activity log:
- `runtimeType` (String, not enum — SwiftData doesn't natively support enum storage)
- `modelName`, `event`, `timestamp`, `ramBytesAtEvent`, `cpuAtEvent`
- Convenience computed properties to convert back to typed enums

**`DetectedProcess` struct** — Internal type produced by `ProcessScanner`, consumed by `DetectionEngine`. Not persisted.

**`ProcessSignature` struct** — Entry in the signature database. Not persisted.

**`PortProbeResult` struct** — Result of an HTTP port probe. Not persisted.

**`HeuristicScore` struct** — Score breakdown for an unknown process. Not persisted.

### Why Strings Instead of Enums in SwiftData

SwiftData's `@Model` macro has limited support for enum-typed properties in some configurations. Storing `runtimeType` and `event` as raw `String` values and providing computed properties for typed access is more robust and avoids migration issues if enum cases are added later.

---

## 8. Persistence Layer

### EventStore

**File:** `Persistence/EventStore.swift`

A `@MainActor` class wrapping a SwiftData `ModelContainer`. Provides three operations:

1. **`log()`** — Inserts a new `EventRecord` and saves immediately
2. **`recentEvents(limit:)`** — Fetches the N most recent events (for dashboard)
3. **`allEvents()`** — Fetches all events (for the full log view)

### Why the Log View Uses `@Query` Instead of `EventStore.recentEvents()`

The `ActivityLogView` uses SwiftUI's `@Query` property wrapper directly:

```swift
@Query(sort: \EventRecord.timestamp, order: .reverse)
private var events: [EventRecord]
```

This is more efficient than manual fetching because `@Query` automatically observes the SwiftData context and updates the view when new records are inserted. No manual refresh needed.

### Data Lifetime

Events are never automatically deleted. For v1, this is acceptable — even at one event per minute (aggressive), a year of logging produces ~525,600 records at ~200 bytes each = ~100 MB. SQLite handles this without issue.

**Planned for v2:** Configurable retention policy (e.g., keep last 30 days).

---

## 9. UI Architecture

### App Entry Point

**File:** `App/LocalAIEventLogApp.swift`

Defines two scenes:
1. **`WindowGroup`** — The main window, identified as `"main"` for programmatic opening
2. **`MenuBarExtra`** — The menu bar icon and popover, using `.menuBarExtraStyle(.window)`

The app is configured as `LSUIElement=YES` (no Dock icon). The only persistent UI element is the menu bar icon.

### Main Window: NavigationSplitView

**Three columns:**
1. **Sidebar (220pt)** — Dashboard, Activity Log, and runtime list with status dots
2. **Content** — Switches between `DashboardView`, `ActivityLogView`, or `RuntimeDetailView` based on sidebar selection
3. **Detail** — `ModelDetailView` for the selected model, or a placeholder

**Why `NavigationSplitView` instead of `TabView` or flat layout:**
- The sidebar provides constant visibility of all detected runtimes
- Three-column layout is the macOS convention for inspector-style apps (Xcode, Finder, Mail)
- Scales naturally — works with 0 runtimes (empty state) and 10+ runtimes equally well

**Considered & rejected:**
- **`TabView`** — Tabs hide information. The user couldn't see all runtimes at a glance
- **Single-page dashboard only** — Doesn't scale when you have many runtimes and models. Need a way to drill into details

### Dashboard View

**Sections:**
1. **Resource Gauges** — Three cards showing CPU, AI RAM, and System Memory with progress bars
2. **Active Models** — Flat list of all loaded models across all runtimes, with metadata badges
3. **Detected Runtimes** — Summary rows showing each runtime's status, version, PID, and resource usage

**Why a dashboard as the default view:**
The most common user intent is "what's running and how much is it using?" The dashboard answers both questions immediately without requiring navigation.

### Menu Bar: `.menuBarExtraStyle(.window)`

**Chosen:** `.window` style (SwiftUI popover panel)

**Why:** The `.window` style gives full SwiftUI layout control — we can show a rich model list, resource bars, and action buttons. The alternative `.menu` style restricts content to `Button`, `Toggle`, and `Divider` only.

**Considered & rejected:**
- **`.menu` style** — Too restrictive. Can't show progress bars, formatted text, or custom layouts
- **Custom `NSPopover`** — Would require dropping to AppKit. SwiftUI's `.window` style provides the same result with less code

### Activity Log: SwiftUI `Table`

Uses the macOS-specific `Table` view for column-based display with sortable headers. Columns: Time, Event, Model, Runtime, RAM.

Filter bar at the top allows filtering by event type (All, Loaded, Unloaded, Started, Stopped).

---

## 10. Widget Architecture

### Data Sharing: App Group + UserDefaults

The main app writes the entire `AppState` as JSON to a shared `UserDefaults` suite (`group.com.laei.LocalAIEventLog`). The widget reads from the same suite.

**Data flow:**
1. Main app's `DetectionEngine` updates `appState`
2. `SharedStateWriter.write()` encodes `AppState` to JSON and writes to shared `UserDefaults`
3. `WidgetCenter.shared.reloadAllTimelines()` triggers widget refresh
4. Widget's `LAEITimelineProvider` reads from shared `UserDefaults` via `SharedStateReader`

**Payload size:** `AppState` serializes to ~2–5 KB of JSON. Well within UserDefaults limits.

**Considered & rejected:**
- **Shared SwiftData store** — SwiftData across processes introduces file locking, migration coordination, and WAL mode complications. The widget only needs a read-only snapshot, not a full database
- **Shared JSON file in App Group container** — Slightly more complex than UserDefaults (need to manage file paths, atomic writes) with no benefit for small payloads
- **Shared framework (dynamic)** — Adds complexity (framework embedding, code signing) for no runtime benefit. Compiling shared source into both targets is simpler

### Widget Refresh Strategy

- **Primary:** Main app calls `WidgetCenter.shared.reloadAllTimelines()` after every state update (~every 5 seconds)
- **Fallback:** Timeline provider sets `.after(30s)` policy in case the main app is not running

**WidgetKit throttling note:** When the app is in the background, WidgetKit limits reloads to ~40–70 per day. When the app is in the foreground, reloads are nearly instant. This is an OS limitation, not a design choice. The 30-second fallback ensures the widget shows *something* even if throttled.

### Widget Sizes

| Size | Content | Rationale |
|------|---------|-----------|
| Small | Brain icon + model count + total RAM | Glanceable status — is anything running? |
| Medium | Model list (top 3) with runtime and per-model RAM | Quick model inventory |
| Large | Per-runtime sections with full model breakdown + totals | Complete overview without opening the app |

---

## 11. Data Flow

### Polling Cadences

| What | Interval | Why |
|------|----------|-----|
| Process scan + port probe | 5s | Balance between responsiveness and overhead. A model load is detected within 5 seconds, which is fast enough that the user perceives it as "instant" |
| Resource sampling | 2s | CPU percentage calculation requires two samples with a time delta. 2s provides smooth gauge updates without excessive syscalls |
| Model identification (API) | 30s | HTTP API calls are heavier than process scanning. Most models stay loaded for minutes/hours, so 30s is frequent enough |
| Widget state write | On every scan (5s) | Keeps the widget current. WidgetKit handles throttling internally |

### State Update Sequence (every 5s)

```
1. ProcessScanner.scan()           → [DetectedProcess]
2. PortProber.probeAll()           → [PortProbeResult]
3. HeuristicDetector (for unmatched PIDs) → [HeuristicScore]
4. Merge & dedup by PID            → [AIRuntime] (preliminary)
5. Diff against previous state     → DetectionEvents
6. Log events to EventStore
7. Fire AlertManager notifications
8. Update published runtimes
9. Recompute AppState
10. Write AppState to App Group
11. Trigger WidgetKit reload
```

Steps 1–3 run concurrently. Steps 4–11 run sequentially on the main actor.

---

## 12. Notifications & Alerts

### AlertManager

**File:** `Monitoring/AlertManager.swift`

An `@Observable` `@MainActor` class that checks resource thresholds and sends macOS notifications.

**Alert types:**
1. **RAM threshold exceeded** — When total AI memory usage exceeds a configurable percentage (default 70%) of system RAM
2. **Runtime appeared** — When a new AI runtime is detected
3. **Model loaded** — When a new model is loaded in any runtime

**Rate limiting:** 60-second cooldown between alerts. Without this, the 5-second polling cycle would spam notifications if a threshold is persistently exceeded.

**Permission:** Uses `UNUserNotificationCenter` with `.alert` and `.sound` options. Permission is requested on first launch.

**Considered & rejected:**
- **`NSUserNotification` (deprecated)** — Removed in macOS 14. `UNUserNotificationCenter` is the modern replacement
- **Growl** — Third-party notification framework, long deprecated
- **No alerts at all** — Defeats a core purpose of the app (knowing when AI models are consuming too much memory)

---

## 13. Concurrency Model

### Actor Isolation

| Component | Isolation | Why |
|-----------|-----------|-----|
| `DetectionEngine` | `@MainActor` | Publishes `@Observable` properties read by SwiftUI views |
| `ProcessScanner` | `actor` | Accesses `libproc` C APIs (not thread-safe) |
| `PortProber` | `actor` | Owns a `URLSession` instance |
| `OllamaModelIdentifier` | `actor` | Owns a `URLSession` instance |
| `LMStudioModelIdentifier` | `actor` | Owns a `URLSession` instance |
| `ResourceMonitor` | `actor` | Maintains mutable `previousCPUSamples` dictionary |
| `EventStore` | `@MainActor` | SwiftData `ModelContext` must be accessed on the main actor |
| `AlertManager` | `@MainActor`, `@Observable` | Publishes observable state + accesses `UNUserNotificationCenter` |

**Why `actor` instead of `class` with locks:**
Swift 6's actors provide compile-time guarantees against data races. Manual locking (`NSLock`, `DispatchQueue`) is error-prone and the compiler can't verify correctness.

**Why `@MainActor` for `DetectionEngine`:**
All SwiftUI property reads happen on the main thread. If `DetectionEngine` were a plain `actor`, every property read from a view would require `await`, which SwiftUI's body doesn't support. `@MainActor` ensures all published state is main-thread-safe by construction.

### Structured Concurrency

Port probing uses `TaskGroup` for concurrent HTTP requests:

```swift
await withTaskGroup(of: PortProbeResult?.self) { group in
    for probe in probes {
        group.addTask { await Self.probePort(probe, session: session) }
    }
    // collect results...
}
```

Timer-based polling uses `Timer.scheduledTimer` with closures that spawn `Task` blocks:

```swift
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    Task { @MainActor in await self.performScan() }
}
```

**Considered & rejected:**
- **`Task.sleep` in a loop** — Works but doesn't integrate with RunLoop, and cancellation is less clean than invalidating a timer
- **Combine `Timer.publish`** — Combine is effectively deprecated in favor of Swift Concurrency. No reason to add a Combine dependency
- **`DispatchSource.makeTimerSource`** — Lower-level than `Timer`, no benefit

---

## 14. Security & Sandboxing

### App Sandbox: DISABLED

LAEI requires system-level access that is incompatible with the macOS App Sandbox:

| Capability | Why Needed | Sandbox Compatible? |
|------------|-----------|-------------------|
| `proc_listallpids()` | Enumerate all processes | No — sandbox blocks process enumeration |
| `proc_pidpath()` | Get executable path of other processes | No — sandbox restricts cross-process queries |
| `sysctl(KERN_PROCARGS2)` | Read command-line arguments of other processes | No — sandbox blocks this for non-child processes |
| `proc_pidinfo(PROC_PIDTASKALLINFO)` | Read CPU/memory of other processes | No — sandbox restricts this to same-user processes only when unsandboxed |
| HTTP to `127.0.0.1` on arbitrary ports | Port probing | Partially — sandbox allows outgoing connections but with restrictions |
| `host_statistics64` | System memory stats | No — sandbox blocks host-level queries |

**Consequence:** LAEI cannot be distributed via the Mac App Store (which requires sandboxing). It must be distributed as:
- A Developer ID-signed and notarized `.app` bundle
- A Homebrew formula
- A direct download from GitHub Releases

**Considered & rejected:**
- **Running with App Sandbox + temporary exceptions** — Apple does not grant `com.apple.security.temporary-exception.mach-lookup` for process enumeration. No exception covers our needs
- **Privileged helper tool** — Could run a sandboxed app with an unsandboxed helper installed via `SMJobBless`. Adds enormous complexity (XPC service, helper installation, privileged escalation dialog) for no user-facing benefit
- **System Extension** — Requires a special Apple entitlement, MDM deployment, and user approval in System Settings. Completely impractical for an open-source utility

### Code Signing

Currently configured for ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`) for development. For distribution:
- Sign with a Developer ID certificate
- Notarize via `xcrun notarytool`
- Staple the notarization ticket via `xcrun stapler`

### Process Access Permissions

All `libproc` and `sysctl` calls work without elevated privileges (no `sudo`) as long as the target processes are owned by the same user. Since local AI runtimes are user-level processes, this is always the case.

---

## 15. Performance Budget

| Operation | Frequency | Measured Cost | Notes |
|-----------|-----------|--------------|-------|
| `proc_listallpids()` | Every 5s | <1ms | Single syscall |
| `proc_name()` × ~500 | Every 5s | ~5ms | Fast name lookup for all PIDs |
| `proc_pidpath()` × ~20 | Every 5s | ~2ms | Only for name-matched candidates |
| `sysctl(KERN_PROCARGS2)` × ~5 | Every 5s | ~0.5ms | Only for path-matched candidates |
| HTTP port probes × 7 | Every 5s | ~50ms worst case | Concurrent, 0.5s timeout for unreachable |
| Heuristic FD check × ~10 | Every 5s | ~20ms | Only high-RSS unidentified processes |
| `proc_pidinfo(TASKALLINFO)` × tracked | Every 2s | ~0.1ms each | Lightweight per-PID |
| Ollama/LM Studio API | Every 30s | ~10ms each | HTTP to localhost |
| JSON encode + UserDefaults write | Every 5s | <1ms | ~2–5 KB payload |
| SwiftData insert | Per event | <1ms | SQLite single-row insert |

**Total CPU overhead per 5s cycle: ~80ms** (<2% of one core at 5-second intervals).

**Memory overhead:** The app itself uses ~20–30 MB RSS (SwiftUI views + SwiftData + URLSession). Negligible compared to the AI models it monitors.

---

## 16. Decisions Log

This section documents every significant design decision, including what was chosen, what was considered, and why alternatives were rejected.

### D1: Polling vs. Event-Driven Process Discovery

**Decision:** Polling every 5 seconds via `proc_listallpids()`

**Alternatives considered:**
| Alternative | Why Rejected |
|-------------|-------------|
| Endpoint Security (`es_subscribe`) | Requires System Extension, Apple entitlement, MDM deployment. Not available to standard apps |
| `kqueue EVFILT_PROC` | Can watch known PIDs for exit, but cannot discover *new* processes. Would need polling anyway |
| `NSWorkspace.didLaunchApplicationNotification` | Only fires for GUI apps with bundle IDs. Misses all CLI AI tools |
| DTrace / `dtrace -n 'proc::exec*'` | Requires `root` access and SIP disabled. Not viable for user-facing apps |
| `audit` / OpenBSM | Requires `root` access |
| Parsing `/var/log/system.log` | Unreliable, delayed, and not guaranteed to contain process events |

**Rationale:** There is no user-accessible push notification API for process creation on macOS. Apple restricts all such APIs to kernel extensions or system extensions with special entitlements. Polling at 5s intervals is the only viable approach, and it's fast enough (<80ms per cycle) to be imperceptible.

### D2: Direct libproc vs. Shell Commands

**Decision:** Call `libproc` C APIs directly from Swift

**Alternative:** Shell out to `ps`, `pgrep`, `lsof`, etc.

**Why rejected:** Each shell command forks a subprocess (1–10ms), pipes stdout, and requires text parsing. For 500 processes at 5-second intervals, this would be 50–100x slower than direct C calls. Shell parsing is also locale-dependent and fragile.

### D3: Separate Widget Target vs. Conditional Compilation

**Decision:** Separate WidgetKit extension target with shared source files

**Alternative:** Single target with `#if WIDGET` conditional compilation

**Why rejected:** Not possible. Apple requires WidgetKit extensions to be separate targets with their own bundle ID, `@main` entry point, and `NSExtensionPointIdentifier` in Info.plist. This is an OS-level constraint.

### D4: App Group + UserDefaults vs. Shared Database

**Decision:** App Group shared `UserDefaults` for widget data

**Alternatives considered:**
| Alternative | Why Rejected |
|-------------|-------------|
| Shared SwiftData store | Cross-process database access introduces file locking, WAL mode coordination, and migration complexity. Widget only needs a read-only snapshot |
| Shared JSON file | Slightly more complex than UserDefaults (file path management, atomic writes) with no benefit for 2–5 KB payloads |
| App Group shared `FileManager.containerURL` with `.json` | Same as above — UserDefaults is simpler for small data |
| CloudKit | Massive overkill. No cloud sync needed |

### D5: @Observable vs. ObservableObject

**Decision:** `@Observable` macro (Observation framework, macOS 14+)

**Alternative:** `ObservableObject` with `@Published`

**Why rejected:** `@Published` triggers view invalidation for *any* property change. Our `DetectionEngine` updates `appState` every 2–5 seconds (resource sampling). With `ObservableObject`, the sidebar would redraw on every resource sample even though the runtime list hasn't changed. `@Observable` only invalidates views that read the specific property that changed, resulting in fewer unnecessary redraws.

### D6: SwiftData vs. Core Data vs. SQLite

**Decision:** SwiftData

**Alternatives considered:**
| Alternative | Why Rejected |
|-------------|-------------|
| Core Data | Older API, more boilerplate. SwiftData is its successor — no reason to use it in a greenfield project |
| Raw SQLite (`sqlite3` C API) | Manual schema management, SQL strings, thread safety. Overkill for simple event logging |
| GRDB.swift | External dependency. System framework (SwiftData) is preferred |
| Flat file (JSON lines) | No querying, no pagination, grows without bound |

### D7: No External Dependencies

**Decision:** Zero third-party packages

**Rationale:**
- Every capability is available in system frameworks
- No supply chain risk (relevant for a security-adjacent monitoring tool)
- No version conflicts or build tool requirements
- Faster CI builds
- Smaller binary size

**Trade-off accepted:** Some convenience features (like a global keyboard shortcut) are deferred to v2 when we'd consider adding `KeyboardShortcuts` by Sindre Sorhus.

### D8: Menu Bar App (LSUIElement) vs. Dock App

**Decision:** `LSUIElement=YES` (menu bar only, no Dock icon)

**Alternative:** Standard Dock app with optional menu bar icon

**Why rejected:** LAEI is a monitoring tool that should run in the background. A Dock icon serves no purpose — the app has no "main" workflow that benefits from Dock presence. Users interact primarily via the menu bar icon (quick glance) or the widget (passive monitoring). The main window is opened on demand.

### D9: Hardened Runtime vs. No Hardened Runtime

**Decision:** Disabled for development builds, enabled for distribution

**For development:** Hardened Runtime with ad-hoc signing causes provisioning profile requirements that complicate local builds. Disabled via `ENABLE_HARDENED_RUNTIME: false` and `CODE_SIGNING_ALLOWED: false`.

**For distribution:** Hardened Runtime is required for notarization. Distribution builds must enable it and sign with a Developer ID certificate.

### D10: Swift 6 Strict Concurrency vs. Swift 5 Mode

**Decision:** Swift 6 with `SWIFT_STRICT_CONCURRENCY=complete`

**Alternative:** Swift 5 mode or `minimal`/`targeted` concurrency checking

**Why rejected:** The detection engine has inherent concurrency — multiple actors polling on different intervals, sharing data through the main actor. Swift 6's strict checking catches races at compile time. Two specific bugs were caught during development:
1. `vm_kernel_page_size` is a global mutable variable that can't be safely accessed from an actor — caught by the compiler, fixed by using `getpagesize()` instead
2. Timer closures needed explicit `@MainActor` annotation to safely access `DetectionEngine` — caught by the compiler

The up-front cost of satisfying the stricter compiler is repaid by confidence in correctness.

### D11: Timer-Based Polling vs. async/await Sleep Loop

**Decision:** `Timer.scheduledTimer` with closures

**Alternative:** `while true { try await Task.sleep(for: .seconds(5)) }`

**Why Timer:** Timers integrate with the RunLoop, which is important for a macOS app. They can be cleanly invalidated (`.invalidate()`), they don't retain `self` when using `[weak self]`, and they're the conventional macOS pattern for periodic work.

**Why not async sleep:** A `Task.sleep` loop requires keeping a `Task` handle and cancelling it explicitly. It also doesn't integrate with RunLoop-driven operations. For UI apps, `Timer` is the idiomatic choice.

### D12: Process Scanner as Actor vs. Struct

**Decision:** `ProcessScanner` is an `actor`

**Why:** Even though the current implementation has no mutable state, making it an actor ensures that if mutable state is added later (e.g., caching previous scan results), the concurrency model doesn't need to change. It also isolates the `libproc` C calls, which may not be thread-safe on all macOS versions.

**Trade-off accepted:** Slight overhead from actor hop (negligible — nanoseconds per call).

---

## Appendix: System API Reference

### libproc APIs Used

| Function | Purpose | Header |
|----------|---------|--------|
| `proc_listallpids` | Enumerate all PIDs | `<libproc.h>` |
| `proc_name` | Get short process name | `<libproc.h>` |
| `proc_pidpath` | Get full executable path | `<libproc.h>` |
| `proc_pidinfo` (with `PROC_PIDTASKALLINFO`) | Get task + BSD info | `<libproc.h>` |

### sysctl APIs Used

| MIB | Purpose |
|-----|---------|
| `CTL_KERN, KERN_PROCARGS2, pid` | Command-line arguments of a process |
| `hw.memsize` (via `sysctlbyname`) | Total physical memory |

### Mach APIs Used

| Function | Purpose |
|----------|---------|
| `host_statistics64(HOST_VM_INFO64)` | VM page statistics (free, active, inactive, wired) |
| `mach_host_self()` | Get host port for statistics call |
| `getpagesize()` | VM page size for byte conversion |
