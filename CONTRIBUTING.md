# Contributing to Vocoder

Thank you for your interest in contributing to Vocoder! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the issue template if available
3. Include:
   - Your operating system and version
   - Python version
   - Steps to reproduce the issue
   - Expected vs actual behavior
   - Relevant log output

### Suggesting Features

1. Check existing feature requests
2. Describe the use case and benefits
3. Consider implementation complexity
4. Be open to discussion and alternatives

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Test thoroughly
5. Update documentation if needed
6. Submit a pull request with clear description

## Development Setup

### Prerequisites

```bash
# System dependencies
sudo dnf install portaudio portaudio-devel sox ydotool

# Python environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Testing

```bash
# Test Option A (script mode)
./scripts/whisper-dictate.sh

# Test Option B (daemon mode)
python3 bin/vocoder &
python3 bin/vocoderctl toggle

# Run diagnostics
./scripts/check-status.sh
```

### Code Style

- Follow PEP 8 for Python code
- Use meaningful variable and function names
- Add docstrings to functions and classes
- Keep functions focused and small
- Comment complex logic

### Documentation

- Update README.md for user-facing changes
- Update technical documentation in docs/developer-guide/
- Keep examples current and working
- Document configuration changes

## Project Structure

```
vocoder/
├── bin/            # Main executables
├── config/         # Configuration files
├── daemon/         # systemd service files
├── docs/           # Documentation
│   ├── user-guide/      # End-user documentation
│   └── developer-guide/ # Technical documentation
└── scripts/        # Helper scripts
```

## Testing Guidelines

### Before Submitting

1. Test both Option A and Option B modes
2. Verify Whisper API integration
3. Test with different audio devices
4. Check systemd service functionality
5. Ensure documentation is accurate

### Integration Tests

```bash
# Port consistency check
grep -r "8771" . --include="*.yaml" --include="*.md"

# Service validation
systemctl --user start vocoder.service
systemctl --user status vocoder.service

# Configuration validation
python3 -c "import yaml; yaml.safe_load(open('config/vocoder.yaml'))"
```

## Commit Guidelines

- Use clear, descriptive commit messages
- Prefix with type: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- Keep commits focused on single changes
- Reference issues when applicable

Example:
```
feat: Add support for custom hotkeys

- Allow users to configure custom keyboard shortcuts
- Update configuration schema
- Add documentation for hotkey customization

Fixes #123
```

## Release Process

1. Update VERSION file
2. Update CHANGELOG.md
3. Create git tag
4. Test installation process
5. Update documentation

## Questions?

Feel free to:
- Open an issue for clarification
- Start a discussion
- Contact maintainers

Thank you for contributing to Vocoder!