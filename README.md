# Flutter-X-Agent 🚀
### Autonomous AI Workspace IDE & Codebase Agent with Hybrid RAG, Multi-Provider Tool Calling, and Dual-Model Adversarial Development

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux-black?style=for-the-badge)](https://flutter.dev/desktop)
[![Multi-Provider](https://img.shields.io/badge/LLMs-Gemini%20%7C%20Claude%20%7C%20Groq%20%7C%20OpenRouter%20%7C%20Ollama-blueviolet?style=for-the-badge)](#-multi-provider-llm-engine)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

---

**Flutter-X-Agent** is an enterprise-grade desktop IDE and autonomous agentic coding workspace built natively in Flutter Desktop. It pairs directly with local repositories, indexes projects using hybrid RAG, reads and modifies code with automatic rollback snapshots, executes terminal commands inside a unified chat stream, and pioneers **Dual-Model Adversarial AI Development (Blue Team Builder vs. Red Team Hacker)** for defense-grade, self-hardened software delivery.

---

## ⚡ Architectural Comparison

| Feature / Capability | Flutter-X-Agent 🚀 | Google Antigravity (AGY) | Claude Code | Cursor / Copilot |
| :--- | :---: | :---: | :---: | :---: |
| **⚔️ Dual-Model Adversarial Arena** *(Blue vs. Red Team)* | ✅ **Built-in (Multi-round self-play)** | ❌ Single-Agent / Manual subagents | ❌ Single-Model | ❌ Single-Model |
| **💬 Unified Chat & Terminal Hub (`xrun`)** | ✅ **Native in-chat shell cards** | ⚠️ Separate terminal panes | ✅ CLI-only | ⚠️ Separate panel |
| **🛡️ Self-Healing Auto-Debug Loop** | ✅ **Autonomous test-fix-verify** | ⚠️ Manual workflow prompts | ⚠️ Manual CLI loop | ❌ Not autonomous |
| **⏪ 1-Click Workspace Safety Snapshots & Rollback** | ✅ **Instant pre-mutation undo** | ⚠️ Git-based only | ⚠️ Git-based only | ⚠️ File timeline |
| **🔍 Visual Side-by-Side Git Diff Viewer** | ✅ **Native visual inspector** | ⚠️ Sidecar diff tool | ❌ Terminal diff only | ✅ Native editor diff |
| **🔑 Multi-Provider Model Orchestration** | ✅ **Gemini, Claude, Groq, OpenRouter, Ollama** | ⚠️ Gemini-focused | ❌ Anthropic-only | ⚠️ Proprietary proxy |
| **🔒 100% Offline & Air-Gapped Privacy** | ✅ **Local Ollama support** | ❌ Cloud-required | ❌ Cloud-required | ❌ Cloud-required |
| **⚡ Free High-Speed Cloud Inference** | ✅ **Groq (450 tok/s) & OpenRouter Free** | ⚠️ Free Tier Quota | ❌ Paid-only | ❌ Paid subscription |
| **🌐 Interactive Web Artifact Sandbox** | ✅ **Live HTML/CSS/JS sandbox** | ⚠️ Generative UI artifacts | ❌ Terminal text only | ⚠️ Browser preview |
| **🔀 AI Conventional Git Commit & Push** | ✅ **One-click status & push** | ⚠️ Via CLI commands | ⚠️ Via bash tool | ⚠️ Git extension |
| **💻 Desktop Native Interface** | ✅ **Flutter Desktop (macOS/Win/Linux)** | ⚠️ Web / Electron | ❌ Terminal CLI | ⚠️ Electron / VS Code |

---

## ⚔️ Dual-Model Adversarial Development (AI Arena)

Traditional single-model coding assistants often suffer from blind spots—producing code with subtle race conditions, unhandled edge cases, memory leaks, or security vulnerabilities. **Flutter-X-Agent solves this through a Dual-Model Adversarial Duel Engine** that pits a builder model against a hacker model in real-time self-play directly inside the main chat stream.

```
                  ┌──────────────────────────────────────────────┐
                  │          USER TASK / REFACTOR PROMPT         │
                  └──────────────────────┬───────────────────────┘
                                         │
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │ 🔵 BLUE TEAM (Lead Architect & Senior Builder) │
                 │ • Inherits Global Active Model (Gemini/Claude) │
                 │ • Generates clean architecture & unit tests    │
                 │ • Refactors code based on Red Team attacks     │
                 └───────────────────────┬────────────────────────┘
                                         │
                         [Proposes Code Implementation]
                                         │
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │ 🔴 RED TEAM (Master Hacker & Security Critic)  │
                 │ • Selected from Dropdown (Groq/Ollama/Claude)  │
                 │ • Hunts injection vectors & security flaws     │
                 │ • Detects race conditions & memory leaks       │
                 │ • Flags O(N²) bottlenecks & widget rebuilds    │
                 └───────────────────────┬────────────────────────┘
                                         │
                       [Exploits & Optimizations Found]
                                         │
                  ┌──────────────────────┴──────────────────────┐
                  │                                             │
      [Flaws Detected (Round < Max)]                 [Consensus / Hardened]
                  │                                             │
                  ▼                                             ▼
          Loop back to Blue Team                      🛡️ Consensus Reached
          for targeted patches                            (100/100 Hardened)
                                                                │
                                                                ▼
                                                    Apply to Disk with Snapshot
```

### 🛡️ How Adversarial Mode Operates:
1. **🔵 Blue Team (Builder / Architect)**: Inherits your global active workspace model (e.g. `Gemini 3.8 Flash`, `Claude 3.5 Sonnet`, `Qwen 2.5 Coder`) to construct clean, idiomatic, fully type-safe code accompanied by unit tests.
2. **🔴 Red Team (Hacker / Security Critic)**: Selected via a dedicated dropdown (e.g. `Groq Qwen-2.5-Coder`, `DeepSeek-R1`, `Llama 3.3-70B`, `Local Ollama`) solely tasked with penetrating, stress-testing, and probing the Blue Team's output.
3. **🎯 Customizable Attack Focus**:
   - **Comprehensive**: Full-spectrum evaluation (Architecture + Security + Speed + Edge cases).
   - **🛡️ Security & Vulnerabilities**: Injections, unsanitized inputs, authorization bypass, secret leakage.
   - **⚡ Performance & $O(N)$ Efficiency**: Loop complexity, unneeded widget rebuilds, redundant I/O.
   - **🧪 Edge Cases & Stress Testing**: Null safety breaches, stream subscription leaks, network dropouts.
4. **🏆 Consensus & Automatic Hardening**: When the Red Team validates that all vulnerabilities have been neutralized, the hardened code is scored (100/100) and presented with 1-click **Apply to File**, **Copy Code**, and **Run Tests**.

---

## 🌟 Superpowers & Core Features

### 1. ⚔️ Single-Chat Adversarial Duel Switch
- Toggle **⚔️ Adversarial Mode** on the fly in the top bar without switching tabs.
- Full duel history, Blue Team proposals, Red Team attack badges, and consensus cards live directly in your unified chat timeline.

### 2. 🛡️ Self-Healing Auto-Debug Loop
- Autonomous test runner and error resolver (`xrun flutter test`, `xrun pytest`, `xrun npm test`).
- Parses compiler outputs, missing imports, assertion failures, and stack traces.
- Automatically edits the broken files, re-runs the test suite, and iterates in a loop until all tests pass with **0 errors**.

### 3. 🔍 Visual Side-by-Side Git Diff Viewer
- Full color-coded before/after file diffs (green for additions, red for deletions).
- Granular inspection of agent modifications with instant file revert and diff inspection.

### 4. ⏪ One-Click Workspace Snapshots & Undo (Rollback History)
- Automatic workspace snapshots captured before every code mutation.
- Single-click **"Rollback Turn"** to restore your workspace to its exact prior state.

### 5. 🔀 AI-Powered Git Commit & Push
- Inspects staged and unstaged `git diff` and `git status`.
- Automatically generates standardized **Conventional Commit messages** (`feat:`, `fix:`, `refactor:`, `docs:`) and pushes to your remote repository with one click.

### 6. ⚡ In-Chat Terminal Hub (`xrun <cmd>`)
- Run shell commands directly inside the chat window by prefixing with `xrun` (e.g., `xrun flutter pub get`, `xrun git status`).
- Displays live stdout/stderr cards, exit status badges, and millisecond execution metrics inline.

### 7. 🧠 Hybrid RAG Knowledge Engine
- Automatically parses and chunks your entire codebase upon opening a folder.
- Combines semantic vector indexing with keyword ranking to inject hyper-relevant context into agent prompts.

### 8. 🌐 Live Web Artifact & HTML/JS Preview
- Instantly renders generated HTML, CSS, JavaScript, SVG, and web apps inside an interactive webview sandbox.

---

## 🔑 Multi-Provider LLM Engine

Bring your own API keys or run completely free & offline models:

| Provider | Supported Models | Access / Pricing | Best For |
| :--- | :--- | :--- | :--- |
| **Google Gemini** | `gemini-3.8-flash`, `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro` | Free Tier / BYOK | Ultra-fast multimodal code generation & RAG |
| **Anthropic Claude** | `claude-3-5-sonnet-20241022`, `claude-3-5-haiku-20241022`, `claude-3-opus` | BYOK (Anthropic Console) | Deep architectural reasoning & refactoring |
| **Groq** | `qwen-2.5-coder-32b`, `llama-3.3-70b-versatile`, `deepseek-r1-distill-llama-70b` | **`[FREE]`** (450 tokens/sec) | Real-time tool loops & fast Red Team attacks |
| **OpenRouter** | `qwen/qwen-2.5-coder-32b:free`, `meta-llama/llama-3.3-70b:free`, `deepseek/deepseek-r1:free` | **`[FREE]`** / BYOK | Free hosted open-weight models |
| **Local Ollama** | `qwen2.5-coder:7b`, `qwen2.5-coder:14b`, `llama3.1:8b`, `deepseek-r1:7b` | **`[100% Free & Offline]`** | Air-gapped, zero-cost, private pair programming |

> **🔒 Privacy Guarantee**: All API keys and preferences are stored locally on your machine using encrypted preferences. **Zero keys, secrets, or codebase telemetry are transmitted or stored externally.**

---

## 🛠️ Tri-Panel Workspace Architecture

```
Flutter-X-Agent
├── 📂 Left Panel: Workspace Explorer
│   ├── Native Directory Picker
│   ├── Hierarchical File Tree with Type Badges
│   └── Live RAG Indexing & Chunk Progress
│
├── 💬 Center Panel: Unified Agent Chat & Adversarial Arena
│   ├── 🤖 Autonomous Tool-Calling Agent Loop
│   ├── ⚔️ Dual-Model Adversarial Arena Switch (Blue Builder vs. Red Hacker)
│   ├── ⚡ In-Chat "xrun <cmd>" Terminal Runner
│   └── 🚀 Quick Action Chips (Self-Healing, Diff, AI Commit)
│
└── 🗂️ Right Panel: 5-Tab Workspace Suite
    ├── 📝 Code Editor & Syntax Viewer
    ├── 🔍 Visual Git Diff Inspector
    ├── 📜 Saved Chat & Duel Histories
    ├── 🌐 Web Artifact & HTML/JS Live Preview
    └── 🧠 RAG Knowledge Base Inspector
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.22 or newer)
- macOS, Linux, or Windows desktop target enabled

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Naveedrj/Flutter-X-Agent.git
   cd Flutter-X-Agent
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Launch the application:**
   ```bash
   # macOS Desktop
   flutter run -d macos

   # Windows Desktop
   flutter run -d windows

   # Linux Desktop
   flutter run -d linux
   ```

4. **Configure your AI Model:**
   - Click the **Settings (⚙️)** icon in the top app bar.
   - Choose your provider (Gemini, Anthropic, Groq, OpenRouter, or Local Ollama).
   - Enter your API Key or select a free hosted/local model from the dynamic dropdown.
   - Toggle **⚔️ Adversarial Mode** in the chat header to start dual-model hardened pair programming!

---

## 🧪 Testing & Verification

Run the full automated test suite covering single-agent mode, dual-model adversarial duel loops, model normalizers, and rollback snapshots:

```bash
flutter test
```

---

## 🗺️ Roadmap & Upcoming Milestones

- [x] Multi-provider LLM orchestration with live model fetching
- [x] In-chat terminal command execution (`xrun`)
- [x] Self-healing test & auto-debug loop
- [x] Side-by-side visual Git diff viewer & snapshot rollback
- [x] Dual-Model Adversarial Arena (Blue vs. Red Team in unified chat)
- [x] Usable model dropdowns with instant fallback resolution
- [ ] Multi-agent Swarm collaboration (Product Manager + Architect + QA bots)
- [ ] AST-level refactoring and semantic code graph navigation
- [ ] CI/CD GitHub Actions bot integration

---

## 🤝 Contributing

Contributions, feature requests, and bug reports are welcome!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'feat: add amazing new feature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.
