# Flutter-X-Agent 🚀
### Autonomous AI Workspace IDE & Codebase Agent with RAG, Tool Calling, and In-Chat Terminal Execution

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)
[![Multi-Provider](https://img.shields.io/badge/LLMs-Gemini%20%7C%20Claude%20%7C%20Groq%20%7C%20OpenRouter%20%7C%20Ollama-blueviolet?style=for-the-badge)](#-multi-provider-llm-engine)

**Flutter-X-Agent** is a next-generation Flutter Desktop application designed for true autonomous pair programming. It connects directly to your local project folder, indexes codebases with hybrid RAG, reads and mutates files with automatic safety snapshots, and executes terminal commands inside an interactive mixed agent-terminal hub.

---

## ⚡ Quick Comparison

![Flutter-X-Agent vs Antigravity vs Claude](docs/images/quick_comparison.png)

---

## 🌟 Superpowers & Killer Features

### 1. 🛡️ Self-Healing & Auto-Debug Loop
- Autonomous test runner and error resolver (`xrun flutter test`, `xrun pytest`, `xrun npm test`).
- Analyzes compiler errors, stack traces, and failing assertions.
- Edits broken files and re-runs the suite in a loop until all tests pass with **0 errors**.

### 2. 🔍 Visual Side-by-Side Git Diff Viewer
- Full color-coded before/after file diffs (green for additions, red for deletions).
- Granular control over agent modifications with instant file revert and diff inspection.

### 3. ⏪ One-Click Snapshot & Undo (Rollback History)
- Automatic workspace snapshots before any code mutation turn.
- Single-click **"Rollback Turn"** to restore your workspace to its exact prior state.

### 4. 🔀 AI-Powered Git Commit & Push
- Analyzes staged and unstaged `git diff` and `git status`.
- Automatically formats clean **Conventional Commit messages** (`feat:`, `fix:`, `refactor:`, `docs:`) and pushes to your remote repository with one click.

### 5. ⚡ Mixed In-Chat Terminal (`xrun <cmd>`)
- Run shell commands right inside the chat window by prefixing with `xrun` (e.g., `xrun flutter pub get`, `xrun git log -n 5`).
- Displays live stdout/stderr cards, exit status badges, and millisecond execution metrics inline.

---

## 🔑 Multi-Provider LLM Engine

Bring your own keys or run completely free & offline models:

| Provider | Supported Models | Access / Pricing |
| :--- | :--- | :--- |
| **Google Gemini** | `gemini-2.5-flash`, `gemini-3.8-flash`, `gemini-2.5-pro` | BYOK (Google AI Studio) |
| **Anthropic Claude** | `claude-3-5-sonnet`, `claude-3-7-sonnet`, `claude-3-haiku` | BYOK (Anthropic Console) |
| **Groq** | `qwen-2.5-coder-32b`, `llama-3.3-70b-versatile`, `deepseek-r1-distill-llama-70b` | **`[FREE]`** (Ultra-fast inference) |
| **OpenRouter** | `deepseek-r1:free`, `meta-llama/llama-3.3-70b:free` | **`[FREE]`** / BYOK |
| **Local Ollama** | `qwen2.5-coder`, `deepseek-coder`, `llama3.2`, `codellama` | **`[100% Free & Offline]`** |

> **Privacy Guarantee**: All API keys and preferences are stored exclusively on your local machine using `shared_preferences`. **Zero keys are transmitted, logged, or pushed to GitHub.**

---

## 🛠️ Architecture

```
Flutter-X-Agent
├── Left Panel: Workspace Explorer
│   ├── Native Directory Picker
│   ├── Hierarchical File Tree & Type Icons
│   └── Live RAG Indexing & Chunk Counter
│
├── Center Panel: Agent Chat & Mixed Terminal Hub
│   ├── AI Autonomous Tool Calling Loop
│   ├── In-chat "xrun <cmd>" Command Runner
│   ├── Live Terminal Output & Exit Code Badges
│   └── Quick Action Chips (Self-Healing, Diff, Commit)
│
└── Right Panel: 5-Tab Workspace Suite
    ├── 📝 Code Editor & Syntax Viewer
    ├── 🔍 Visual Git Diff Inspector
    ├── 🗂️ Saved Chat Histories
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

2. **Install Flutter dependencies:**
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

---

## 🤝 Contributing
Contributions, bug reports, and feature requests are welcome! Feel free to open an issue or submit a pull request.

---

## 📄 License
This project is open source and available under the [MIT License](LICENSE).
