# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Nature

This is a **PRP (Product Requirement Prompt) Framework** repository, not a traditional software project. The core concept: **"PRP = PRD + curated codebase intelligence + agent/runbook"** - designed to enable AI agents to ship production-ready code on the first pass.

## Core Architecture

### Command-Driven System

- **pre-configured Claude Code commands** in `.claude/commands/`
- Commands organized by function:
  - `PRPs/` - PRP creation and execution workflows
  - `development/` - Core development utilities (prime-core, onboarding, debug)
  - `code-quality/` - Review and refactoring commands
  - `rapid-development/experimental/` - Parallel PRP creation and hackathon tools
  - `git-operations/` - Conflict resolution and smart git operations

### Template-Based Methodology

- **PRP Templates** in `PRPs/templates/` follow structured format with validation loops
- **Context-Rich Approach**: Every PRP must include comprehensive documentation, examples, and gotchas
- **Validation-First Design**: Each PRP contains executable validation gates (syntax, tests, integration)

### AI Documentation Curation

- `PRPs/ai_docs/` contains curated Claude Code documentation for context injection
- `claude_md_files/` provides framework-specific CLAUDE.md examples

## Development Commands

### PRP Execution

```bash
# Interactive mode (recommended for development)
uv run PRPs/scripts/prp_runner.py --prp [prp-name] --interactive

# Headless mode (for CI/CD)
uv run PRPs/scripts/prp_runner.py --prp [prp-name] --output-format json

# Streaming JSON (for real-time monitoring)
uv run PRPs/scripts/prp_runner.py --prp [prp-name] --output-format stream-json
```

### Key Claude Commands

- `/prp-base-create` - Generate comprehensive PRPs with research
- `/prp-base-execute` - Execute PRPs against codebase
- `/prp-planning-create` - Create planning documents with diagrams
- `/prime-core` - Prime Claude with project context
- `/review-staged-unstaged` - Review git changes using PRP methodology

## Critical Success Patterns

### The PRP Methodology

1. **Context is King**: Include ALL necessary documentation, examples, and caveats
2. **Validation Loops**: Provide executable tests/lints the AI can run and fix
3. **Information Dense**: Use keywords and patterns from the codebase
4. **Progressive Success**: Start simple, validate, then enhance

### PRP Structure Requirements

- **Goal**: Specific end state and desires
- **Why**: Business value and user impact
- **What**: User-visible behavior and technical requirements
- **All Needed Context**: Documentation URLs, code examples, gotchas, patterns
- **Implementation Blueprint**: Pseudocode with critical details and task lists
- **Validation Loop**: Executable commands for syntax, tests, integration

### Validation Gates (Must be Executable)

```bash
# Level 1: Syntax & Style
ruff check --fix && mypy .

# Level 2: Unit Tests
uv run pytest tests/ -v

# Level 3: Integration
uv run uvicorn main:app --reload
curl -X POST http://localhost:8000/endpoint -H "Content-Type: application/json" -d '{...}'

# Level 4: Deployment
# mcp servers, or other creative ways to self validate
```

## Anti-Patterns to Avoid

- L Don't create minimal context prompts - context is everything - the PRP must be comprehensive and self-contained, reference relevant documentation and examples.
- L Don't skip validation steps - they're critical for one-pass success - The better The AI is at running the validation loop, the more likely it is to succeed.
- L Don't ignore the structured PRP format - it's battle-tested
- L Don't create new patterns when existing templates work
- L Don't hardcode values that should be config
- L Don't catch all exceptions - be specific

## Working with This Framework

### When Creating new PRPs

1. **Context Process**: New PRPs must consist of context sections, Context is King!
2.

### When Executing PRPs

1. **Load PRP**: Read and understand all context and requirements
2. **ULTRATHINK**: Create comprehensive plan, break down into todos, use subagents, batch tool etc check prps/ai_docs/
3. **Execute**: Implement following the blueprint
4. **Validate**: Run each validation command, fix failures
5. **Complete**: Ensure all checklist items done

### Command Usage

- Read the .claude/commands directory
- Access via `/` prefix in Claude Code
- Commands are self-documenting with argument placeholders
- Use parallel creation commands for rapid development
- Leverage existing review and refactoring commands

## Project Structure Understanding

```
PRPs-agentic-eng/
.claude/
  commands/           # 28+ Claude Code commands
  settings.local.json # Tool permissions
PRPs/
  templates/          # PRP templates with validation
  scripts/           # PRP runner and utilities
  ai_docs/           # Curated Claude Code documentation
   *.md               # Active and example PRPs
 claude_md_files/        # Framework-specific CLAUDE.md examples
 pyproject.toml         # Python package configuration
```

Remember: This framework is about **one-pass implementation success through comprehensive context and validation**. Every PRP should contain the exact context for an AI agent to successfully implement working code in a single pass.

# Project-Specific Instructions

Project root: /home/ice/dev/vocoder

# Vocoder Project Configuration

This is a vocoder synthesis project using the PRP framework.

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
