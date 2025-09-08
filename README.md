# Vocoder

Fast voice dictation for Linux with push-to-talk functionality.

## Features

- 🎙️ **Push-to-talk voice dictation** - Press Super+Space to dictate
- ⚡ **Dual-mode operation** - Choose between simple script or instant daemon
- 🔇 **Smart silence detection** - Automatically stops after 2 seconds of silence  
- 🖥️ **Wayland native** - Full support via ydotool
- 📋 **Clipboard fallback** - Copies text if typing fails
- 🚀 **Sub-50ms response** - In daemon mode

## Quick Start

```bash
# One-line install
curl -sSL https://raw.githubusercontent.com/arealicehole/vocoder/main/install.sh | bash

# Test dictation
./scripts/whisper-dictate.sh

# Use hotkey: Press Super+Space and speak
```

## Requirements

- Linux with PulseAudio/ALSA
- Whisper API service on port 8771
- Python 3.9+

## Installation

```bash
git clone https://github.com/arealicehole/vocoder.git
cd vocoder
./install.sh
```

See [INSTALL.md](INSTALL.md) for detailed instructions.

## Usage

1. **Focus any text field** (browser, editor, terminal)
2. **Press Super+Space**
3. **Speak clearly**
4. **Stop speaking** - auto-stops after silence
5. **Text appears** at cursor

## Documentation

### User Guides
- [Quick Start Guide](docs/user-guide/quick-start.md)
- [Configuration](docs/user-guide/configuration.md)
- [Troubleshooting](docs/user-guide/troubleshooting.md)

### Developer Guides
- [Architecture](docs/developer-guide/architecture.md)
- [Development](docs/developer-guide/development.md)
- [systemd Service](docs/developer-guide/systemd-service.md)

### Reference
- [Commands Reference](COMMANDS.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## Configuration

Edit `config/vocoder.yaml`:

```yaml
whisper_url: "http://127.0.0.1:8771/v1/transcribe"
audio:
  gain_db: 15.0  # Adjust for your microphone
silence:
  stop_threshold: 2.0  # Seconds of silence to stop
```

## Operating Modes

### Option A: Simple Script (Default)
- Reliable and easy to debug
- 1-2 second startup time
- No background processes

### Option B: Daemon Mode
- Instant response (<50ms)
- Persistent background service
- Advanced features

Switch to daemon mode:
```bash
systemctl --user enable --now vocoder.service
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT - See [LICENSE](LICENSE) file.

## Support

- [Report Issues](https://github.com/arealicehole/vocoder/issues)
- [Discussions](https://github.com/arealicehole/vocoder/discussions)

## Acknowledgments

Built with Whisper API for transcription and ydotool for Wayland compatibility.