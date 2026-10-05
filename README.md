# Flutter-X-Agent 🚀
### Autonomous AI Workspace IDE & Codebase Agent with RAG, Tool Calling & Terminal Execution

**Flutter-X-Agent** is a modern Flutter Desktop application designed for pair programming with an autonomous AI Agent. It indexes local repositories with hybrid RAG, reads, writes, edits, and moves files, and executes terminal commands directly inside your selected workspace folder.

---

## ✨ Key Features

- 📂 **Workspace File Explorer**: Select any folder from machine storage, browse hierarchical file trees with file-type icons, and manage files.
- 💬 **Center-Stage Agent Chat**: Interactive AI Agent with autonomous multi-step tool execution.
- ⚡ **Mixed "xrun" Terminal Command Runner**: Type `xrun <command>` (e.g., `xrun flutter pub get`, `xrun git status`) directly in the chat box to execute shell commands with live stdout/stderr cards, exit badges, and millisecond metrics.
- 📝 **Built-in Code Editor & Viewer**: Syntax highlighting, line numbers, editing, and file saving.
- 🧠 **Hybrid RAG Knowledge Engine**: Lexical BM25/TF-IDF and semantic vector embeddings for codebase chunking and context retrieval.
- 🌐 **Web View & Artifact Preview**: Live rendering for agent-generated HTML/CSS/JS web components and markdown artifacts.
- 🗂️ **Saved Chat Session Manager**: Persistent chat histories with instant switching and deletion.
- 🔑 **Multi-Provider LLM Support**: Works with Gemini, Anthropic (Claude), Groq, OpenRouter, and Local Ollama.

---

## 🛠️ Architecture

```
Flutter-X-Agent
├── Left Panel: Workspace Explorer
│   ├── Native Directory Picker (FilePicker)
│   ├── Recursive File Tree Hierarchy
│   └── Live RAG Indexing Indicator
│
├── Center Panel: Agent Chat & Terminal Hub
│   ├── AI Multi-step Tool Calling Loop
│   ├── Inline "xrun <cmd>" Shell Runner
│   ├── Colored stdout/stderr Terminal Output Cards
│   └── Quick Action Chips
│
└── Right Panel: Workspace Suite Deck
    ├── 📝 Code Editor & Syntax Highlighting
    ├── 🗂️ Saved Chat Sessions
    ├── 🌐 HTML/Web View Artifact Preview
    └── 🧠 RAG Knowledge Base Inspector
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.22+)
- macOS, Linux, or Windows desktop target enabled

### Installation
```bash
# Clone the repository
git clone https://github.com/Naveedrj/Flutter-X-Agent.git
cd Flutter-X-Agent

# Install dependencies
flutter pub get

# Run on macOS Desktop
flutter run -d macos
```

---

## 🔒 Security & Privacy
No API keys or personal credentials are hardcoded in the codebase. All keys are stored securely on the local device via `shared_preferences`.

---

## 📄 License
MIT License.
