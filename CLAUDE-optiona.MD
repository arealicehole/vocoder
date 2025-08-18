# CLAUDE.md: Project Configuration

## 1. Project Identity & Core Principles
- **Project Goal:** Provide a hotkey-triggered voice dictation system on Linux that transcribes speech with Whisper Tiny and types directly into any text box.
- **Core Principles:** Minimal latency, compatibility with GNOME (and noting Sway/KDE deltas), reliable auto-stop on silence.
- **Key Terminology:** 
  - *ydotool*: simulates keystrokes.
  - *wtype*: lightweight typing alternative for Wayland.
  - *Whisper API*: local ASR service running on 127.0.0.1:8765.

## 2. Tech Stack
- **Language:** Bash
- **Framework(s):** None (system utilities only)
- **Database:** None
- **Styling:** N/A
- **Testing:** Manual validation in GNOME text fields
- **Infrastructure:** 
  - Local Whisper server (tiny model)
  - ydotool or wtype for typing output
  - sox for recording with silence detection

## 3. Project Structure
- **Directory Layout:**
  - `scripts/whisper-dictate.sh` → main hotkey-triggered dictation script
- **Architectural Patterns:** Single-shot script, no daemon
- **Exemplary Files:** `examples/option-a-dictation.md` (usage example)

## 4. Operational Directives: Commands & Workflows
- **Commands:**
  ```bash
  ./scripts/whisper-dictate.sh   # record, transcribe, type

    Workflows:

        Git: Feature branches per option

        Pull Requests: Document with INITIAL.md per feature

5. Structural & Stylistic Mandates

    Formatting & Linting: Shellcheck for bash scripts

    Naming Conventions: kebab-case for scripts

    API Design: Single POST to /v1/transcribe

    State Management: None

6. Guardrails: The "Do Not" Section

    Do not store transcriptions in clipboard (must type directly).

    Do not rely on X11-only tools (must support Wayland).

    Do not bind hotkeys outside GNOME media-keys schema.

7. Modular Context Imports

    @Linux Whisper Dictation Hotkey Setup.md



