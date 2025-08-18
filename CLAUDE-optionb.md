# CLAUDE.md: Project Configuration

## 1. Project Identity & Core Principles
- **Project Goal:** Provide a persistent, low-latency voice dictation daemon (`vocoder`) with a control utility (`vocoderctl`) for hotkey-triggered push-to-talk dictation.
- **Core Principles:** 
  - Keep Whisper service hot for immediate transcription
  - Use systemd user services for reliability
  - Maintain seamless typing into any focused text field
- **Key Terminology:** 
  - *vocoder*: daemon process
  - *vocoderctl*: CLI client for IPC with vocoder
  - *wtype*: Wayland typing injector

## 2. Tech Stack
- **Language:** Python or Go for daemon, Bash for helper scripts
- **Framework(s):** systemd user services
- **Database:** None
- **Styling:** N/A
- **Testing:** Manual PTT dictation in editors and browsers
- **Infrastructure:** 
  - Persistent daemon
  - Local Whisper service
  - wtype injection

## 3. Project Structure
- **Directory Layout:**
  - `daemon/vocoder.service` → systemd unit
  - `bin/vocoder` → persistent process
  - `bin/vocoderctl` → command-line client
- **Architectural Patterns:** Daemon + IPC + CLI client
- **Exemplary Files:** `examples/option-b-pushtotalk.md`

## 4. Operational Directives: Commands & Workflows
- **Commands:**
  ```bash
  systemctl --user enable --now vocoder.service
  vocoderctl start   # begin recording/transcription
  vocoderctl stop    # stop recording

    Workflows:

        Git: Branch feature/vocoder-daemon

        Pull Requests: Document with INITIAL.md for transition A→B

5. Structural & Stylistic Mandates

    Formatting & Linting: black (Python) or gofmt

    Naming Conventions: snake_case for Python, kebab-case for shell

    API Design: vocoderctl <command>

    State Management: Maintained in daemon runtime

6. Guardrails: The "Do Not" Section

    Do not re-spawn Whisper per invocation (keep hot).

    Do not bypass vocoderctl for hotkeys.

    Do not mix clipboard fallback into daemon pipeline.

7. Modular Context Imports

    @Linux Whisper Dictation Hotkey Setup.md
