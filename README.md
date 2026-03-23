# LAEI — Local AI Event Log

A native macOS application that monitors, logs, and displays all locally running AI models and runtimes in one place.

## The Problem

The local AI ecosystem is fragmented. Users commonly run multiple tools simultaneously — Ollama, LM Studio, llama.cpp, MLX-based servers, and more — each with its own UI or CLI. Every one of these loads large language models into memory (often 4–12 GB each), and on a machine with 16–32 GB of unified memory, two forgotten models can silently consume most of your RAM.

There is no unified view. You might have:
- An Ollama model loaded from a terminal session you forgot about
- LM Studio serving a model in the background
- A Python script running MLX inference
- A llamafile you launched to test something

LAEI solves this by providing a **single pane of glass** for all local AI activity — showing what's running, how much memory it's using, and alerting you when things get heavy.

## Features

### Multi-Runtime Detection
LAEI detects AI runtimes through three complementary strategies:

- **Process scanning** — Enumerates all running processes via macOS `libproc` APIs and matches against a database of 14+ known AI runtime signatures (process names, executable paths, command-line arguments)
- **Port probing** — Sends lightweight HTTP health checks to known AI service ports (11434 for Ollama, 1234 for LM Studio, 8080 for llama.cpp, etc.)
- **Heuristic detection** — Catches unknown/new AI tools by scoring processes based on signals like open `.gguf` files, high memory usage, Metal GPU activity, and AI-related command-line arguments

### Supported Runtimes
| Runtime | Detection Method | Model Identification |
|---------|-----------------|---------------------|
| Ollama | Process + Port (11434) | REST API (`/api/ps`) — name, params, quantization, VRAM |
| LM Studio | Process + Port (1234) | OpenAI API (`/v1/models`) — model ID |
| llama.cpp | Process + Port (8080) | Command-line arg parsing (`--model`) |
| GPT4All | Process + Port (4891) | OpenAI API |
| KoboldCpp | Process + Port (5001) | API + args |
| Text Generation WebUI | Process args | Port probe (7860) |
| Jan | Process + Port (1337) | OpenAI API |
| Msty | Process | — |
| MLX | Process args (`mlx_lm`) | Command-line parsing |
| Llamafile | Process | Command-line parsing |
| LocalAI | Process + Port (8585) | OpenAI API |
| vLLM | Process args | Port probe |
| Open WebUI | Process args | Port probe (3001) |
| AnythingLLM | Process | Port probe (3000) |
| *Unknown* | Heuristic scoring | — |

### Three UI Surfaces

#### Menu Bar
- Always-visible brain icon in the macOS menu bar
- Changes appearance when AI models are active
- Shows model count badge
- Click to open a popover with full model list and resource summary
- Quick access to open the main window or quit

#### Main Window
- **Dashboard** — System resource overview (CPU, RAM gauges), list of all active models with per-model metadata, detected runtimes summary
- **Runtime Detail** — Per-runtime view showing loaded models with parameter count, quantization level, VRAM usage; resource bars for CPU, RAM, threads
- **Model Detail** — Deep metadata view for individual models — parameters, quantization, context length, file size, VRAM, load time
- **Activity Log** — Persistent event log (SwiftData/SQLite) of all model load/unload and runtime start/stop events, with filtering and resource snapshots at event time

#### Desktop Widgets (WidgetKit)
- **Small** — Active indicator icon, model count, total RAM usage
- **Medium** — Model list with per-model runtime and memory
- **Large** — Per-runtime sections with full model breakdown, resource totals, last-updated timestamp

### Resource Monitoring
- Per-process CPU usage (computed from `proc_pidinfo` task time deltas)
- Per-process resident memory (RSS)
- System-wide memory pressure (free + inactive pages via `host_statistics64`)
- Thread count per runtime

### Alerts & Notifications
- Configurable RAM threshold (default 70%) — alerts when AI models collectively exceed the threshold
- Notifications when new runtimes are detected
- Notifications when models are loaded
- Rate-limited to avoid notification spam (60-second cooldown)

### System Integration
- **Launch at Login** via `SMAppService` (modern macOS 13+ API)
- **LSUIElement** — Runs as a menu bar app (no Dock icon)
- **Settings** — Configurable RAM threshold, launch-at-login toggle

## Requirements

- **macOS 14.0 (Sonoma)** or later
- **Apple Silicon** recommended (Intel Macs supported)
- **Xcode 15.0+** for building from source
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

## Building

```bash
# Clone the repository
git clone https://github.com/slavko-at-klincov-it/LAEI-LocalAIEventLog.git
cd LAEI-LocalAIEventLog

# Generate Xcode project
xcodegen generate

# Build from command line
xcodebuild -project LocalAIEventLog.xcodeproj \
  -scheme LocalAIEventLog \
  -destination 'platform=macOS,arch=arm64' \
  build

# Or open in Xcode
open LocalAIEventLog.xcodeproj
```

## Usage

1. **Build and run** the app from Xcode or via `xcodebuild`
2. A **brain icon** appears in your menu bar
3. The app immediately starts scanning for local AI runtimes
4. **Click the menu bar icon** to see a summary of running models
5. **Click "Open Local AI Event Log..."** to open the full dashboard
6. **Add the widget** to your desktop via the macOS widget gallery (Edit Widgets > search "Local AI Monitor")

### What Gets Detected

LAEI scans every 5 seconds for:
- Running processes matching known AI runtime signatures
- HTTP services on known AI ports
- Unknown processes with AI-like characteristics (large memory, `.gguf` files, Metal GPU usage)

Model metadata (names, parameters, quantization) is queried every 30 seconds via runtime APIs. Resource usage is sampled every 2 seconds.

## Project Structure

```
LocalAIEventLog/
├── project.yml                         # XcodeGen project specification
├── LocalAIEventLog/                    # Main App Target
│   ├── App/                            # App entry point, Info.plist, entitlements
│   ├── Models/                         # EventRecord (SwiftData)
│   ├── Detection/                      # Detection engine
│   │   ├── SystemBridge/               # Swift wrappers for C libproc/sysctl APIs
│   │   ├── ModelIdentifiers/           # Per-runtime model identification (Ollama, LM Studio, CLI)
│   │   ├── DetectionEngine.swift       # Central coordinator
│   │   ├── ProcessScanner.swift        # libproc process enumeration
│   │   ├── ProcessSignatureDB.swift    # Known runtime signature database
│   │   ├── PortProber.swift            # HTTP port health checks
│   │   └── HeuristicDetector.swift     # Unknown AI workload scoring
│   ├── Monitoring/                     # Resource monitoring + alerts
│   ├── Persistence/                    # SwiftData event store
│   ├── Views/                          # SwiftUI views (MenuBar, MainWindow, Shared)
│   ├── Services/                       # Widget state writer
│   └── Utilities/                      # Formatting helpers
├── LocalAIEventLogShared/              # Shared code (App + Widget)
│   ├── AIRuntime.swift                 # Runtime type enum + runtime struct
│   ├── AIModel.swift                   # Model data type
│   ├── ResourceUsage.swift             # Resource snapshot type
│   ├── AppState.swift                  # Aggregate state for widget sharing
│   ├── AppGroupConstants.swift         # App Group identifiers
│   └── SharedStateReader.swift         # Widget reads state from App Group
├── LocalAIEventLogWidget/              # WidgetKit Extension
│   ├── LAEIWidget.swift                # Widget configuration
│   ├── TimelineProvider.swift          # WidgetKit data pipeline
│   ├── SmallWidgetView.swift
│   ├── MediumWidgetView.swift
│   └── LargeWidgetView.swift
└── LocalAIEventLogTests/              # Unit tests
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for full technical documentation including design decisions and rationale.

## Roadmap (v2+)

- **API Consumer Detection** — Identify which applications are calling AI runtimes (e.g., "VS Code is using Ollama")
- **Timeline View** — Visual Gantt-chart history of model load/unload events over time
- **Capacity Estimator** — "Room for ~1 more 7B Q4 model" based on available memory
- **Model Download Progress** — Monitor `ollama pull` and LM Studio downloads
- **AppleScript / Shortcuts** — "Hey Siri, what AI models are running?"
- **Export** — CSV/JSON export of event logs
- **Process Kill** — One-click stop for AI processes from the UI

## License

MIT

## Contributing

Contributions welcome. Please open an issue first to discuss what you'd like to change.
