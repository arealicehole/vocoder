# Development Guide

Setup and workflow for developing Vocoder.

## Development Environment

### Prerequisites

```bash
# System packages (Fedora)
sudo dnf install python3-devel portaudio-devel sox ydotool git

# System packages (Ubuntu)
sudo apt install python3-dev portaudio19-dev sox ydotool git

# Python version
python3 --version  # Requires 3.9+
```

### Clone and Setup

```bash
# Clone repository
git clone https://github.com/arealicehole/vocoder.git
cd vocoder

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Development dependencies
pip install pytest black mypy pylint
```

### IDE Configuration

#### VS Code

`.vscode/settings.json`:
```json
{
  "python.defaultInterpreter": "${workspaceFolder}/.venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "editor.formatOnSave": true,
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

#### PyCharm

1. Set Project Interpreter to `.venv/bin/python`
2. Enable Black formatter
3. Configure pylint as external tool

## Project Structure

```
vocoder/
├── bin/                 # Executables
│   ├── vocoder         # Main daemon (Python)
│   └── vocoderctl      # Control client (Python)
├── config/             # Configuration
│   └── vocoder.yaml    # Main config file
├── daemon/             # Service files
│   └── vocoder.service # systemd unit
├── docs/               # Documentation
│   ├── user-guide/     # End-user docs
│   └── developer-guide/# Technical docs
├── scripts/            # Shell scripts
│   ├── whisper-dictate.sh  # Option A
│   └── *.sh           # Utilities
├── tests/              # Test files
│   ├── test_audio.py   # Audio tests
│   └── test_daemon.py  # Daemon tests
└── lib/                # Shared libraries
    └── vocoder/        # Python modules
```

## Code Style

### Python Style Guide

Follow PEP 8 with these additions:

```python
# Imports
import os
import sys
from typing import Optional, List, Dict

import numpy as np
import sounddevice as sd

from vocoder.config import Config
from vocoder.audio import AudioRecorder

# Class naming
class AudioProcessor:  # PascalCase
    pass

# Function naming
def process_audio(data: np.ndarray) -> np.ndarray:  # snake_case
    pass

# Constants
MAX_DURATION = 30  # UPPER_CASE
DEFAULT_SAMPLE_RATE = 16000

# Type hints
def record(duration: float, device: Optional[int] = None) -> np.ndarray:
    pass
```

### Bash Style Guide

```bash
#!/usr/bin/env bash
set -euo pipefail  # Always use strict mode

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WHISPER_URL="${WHISPER_URL:-http://127.0.0.1:8771/v1/transcribe}"

# Functions
function cleanup() {
    rm -f "${TEMP_FILE}"
}
trap cleanup EXIT

# Error handling
if ! command -v sox &> /dev/null; then
    echo "Error: sox not installed" >&2
    exit 1
fi
```

## Testing

### Unit Tests

Create `tests/test_audio.py`:

```python
import pytest
import numpy as np
from vocoder.audio import AudioRecorder, detect_silence

class TestAudioRecorder:
    def test_initialization(self):
        recorder = AudioRecorder()
        assert recorder.sample_rate == 16000
        assert recorder.channels == 1
    
    def test_silence_detection(self):
        # Silent audio
        silent = np.zeros(1000)
        assert detect_silence(silent, threshold=0.02) == True
        
        # Loud audio
        loud = np.ones(1000) * 0.5
        assert detect_silence(loud, threshold=0.02) == False
    
    @pytest.fixture
    def mock_device(self, monkeypatch):
        def mock_query_devices():
            return [
                {'name': 'Monitor', 'max_input_channels': 2},
                {'name': 'Microphone', 'max_input_channels': 1}
            ]
        monkeypatch.setattr('sounddevice.query_devices', mock_query_devices)
```

Run tests:
```bash
pytest tests/ -v
pytest tests/ --cov=vocoder  # With coverage
```

### Integration Tests

```python
# tests/test_integration.py
import subprocess
import time
import socket

def test_daemon_startup():
    # Start daemon
    proc = subprocess.Popen(['python3', 'bin/vocoder'])
    time.sleep(2)
    
    # Check socket exists
    assert os.path.exists('/run/user/1000/vocoder.sock')
    
    # Test connection
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect('/run/user/1000/vocoder.sock')
    sock.close()
    
    # Cleanup
    proc.terminate()

def test_whisper_api():
    response = requests.get('http://127.0.0.1:8771/health')
    assert response.status_code == 200
```

### Manual Testing

```bash
# Test audio recording
python3 -c "
import sounddevice as sd
import numpy as np
audio = sd.rec(16000, samplerate=16000, channels=1)
sd.wait()
print(f'Max amplitude: {np.max(np.abs(audio)):.6f}')
"

# Test daemon
python3 bin/vocoder &
sleep 2
python3 bin/vocoderctl status
python3 bin/vocoderctl toggle
kill %1

# Test script
timeout 5s ./scripts/whisper-dictate.sh
```

## Debugging

### Debug Mode

```python
# Add debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

class AudioRecorder:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initializing AudioRecorder")
```

Run with debug:
```bash
DEBUG=1 python3 bin/vocoder
PYTHONUNBUFFERED=1 python3 bin/vocoder 2>&1 | tee debug.log
```

### Common Issues

#### Audio Device Issues

```python
# Debug script
import sounddevice as sd

print("Available devices:")
for i, device in enumerate(sd.query_devices()):
    if device['max_input_channels'] > 0:
        print(f"  {i}: {device['name']} (inputs: {device['max_input_channels']})")

# Test specific device
device_id = 1
try:
    audio = sd.rec(1000, device=device_id)
    sd.wait()
    print(f"Device {device_id} works")
except Exception as e:
    print(f"Device {device_id} failed: {e}")
```

#### Socket Issues

```python
# Debug socket
import socket
import os

socket_path = '/run/user/1000/vocoder.sock'

# Check if exists
if os.path.exists(socket_path):
    print(f"Socket exists: {socket_path}")
    # Try to connect
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(socket_path)
        print("Connected successfully")
        sock.close()
    except Exception as e:
        print(f"Connection failed: {e}")
else:
    print("Socket does not exist")
```

### Profiling

```python
# Performance profiling
import cProfile
import pstats

def profile_function():
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Code to profile
    record_audio(duration=5)
    
    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumulative')
    stats.print_stats(10)
```

## Building and Packaging

### Create Distribution

```bash
# Update version
echo "1.1.0" > VERSION

# Create source distribution
python3 -m build --sdist

# Create wheel
python3 -m build --wheel

# Files created in dist/
ls dist/
# vocoder-1.1.0.tar.gz
# vocoder-1.1.0-py3-none-any.whl
```

### Install Package

```bash
# Install from source
pip install .

# Install editable (development)
pip install -e .

# Install from wheel
pip install dist/vocoder-1.1.0-py3-none-any.whl
```

## Release Process

### Version Bumping

```bash
# Update VERSION file
echo "1.1.0" > VERSION

# Update pyproject.toml
sed -i 's/version = "[0-9.]*"/version = "1.1.0"/' pyproject.toml

# Update CHANGELOG.md
# Add new version section with changes
```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
git add -p  # Interactive staging
git commit -m "feat: Add new feature"

# Run tests
pytest tests/
./scripts/test-all.sh

# Push and create PR
git push origin feature/new-feature
# Create PR on GitHub
```

### Release Checklist

- [ ] Update VERSION file
- [ ] Update CHANGELOG.md
- [ ] Run all tests
- [ ] Test installation script
- [ ] Test both Option A and B
- [ ] Create git tag
- [ ] Push to GitHub
- [ ] Create GitHub release
- [ ] Update documentation

## Contributing

### Setting Up Fork

```bash
# Fork on GitHub, then:
git clone https://github.com/YOUR_USERNAME/vocoder.git
cd vocoder
git remote add upstream https://github.com/arealicehole/vocoder.git

# Keep fork updated
git fetch upstream
git checkout main
git merge upstream/main
```

### Pull Request Process

1. Create feature branch
2. Make changes with tests
3. Update documentation
4. Run linters and tests
5. Submit PR with description

### Code Review

Before submitting:

```bash
# Format code
black bin/ lib/

# Type checking
mypy bin/ lib/

# Linting
pylint bin/ lib/

# Tests
pytest tests/ -v
```

## Performance Optimization

### Audio Processing

```python
# Use NumPy efficiently
# Bad
result = []
for sample in audio:
    result.append(sample * gain)

# Good
result = audio * gain  # Vectorized

# Memory efficient recording
class AudioBuffer:
    def __init__(self, max_size):
        self.buffer = np.zeros(max_size, dtype=np.float32)
        self.position = 0
    
    def append(self, data):
        # Circular buffer implementation
        pass
```

### Async Operations

```python
import asyncio
import httpx

async def transcribe_async(audio_data):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            'http://127.0.0.1:8771/v1/transcribe',
            files={'audio': audio_data}
        )
        return response.json()
```

## Monitoring

### Metrics Collection

```python
import time
from dataclasses import dataclass

@dataclass
class Metrics:
    recordings_total: int = 0
    recordings_failed: int = 0
    average_duration: float = 0.0
    average_latency: float = 0.0

    def record_success(self, duration, latency):
        self.recordings_total += 1
        self.average_duration = (
            (self.average_duration * (self.recordings_total - 1) + duration) 
            / self.recordings_total
        )
        self.average_latency = (
            (self.average_latency * (self.recordings_total - 1) + latency)
            / self.recordings_total
        )
```

### Health Checks

```python
def health_check():
    checks = {
        'audio': check_audio_device(),
        'whisper': check_whisper_api(),
        'socket': check_socket(),
        'typing': check_typing_tool()
    }
    
    return all(checks.values()), checks
```

## Troubleshooting Development

### Virtual Environment Issues

```bash
# Recreate venv
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Import Errors

```bash
# Add to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)/lib"

# Or in code
import sys
sys.path.insert(0, '/home/ice/dev/vocoder/lib')
```

### Permission Issues

```bash
# Fix script permissions
chmod +x scripts/*.sh
chmod +x bin/vocoder bin/vocoderctl

# Fix socket permissions
chmod 600 /run/user/$(id -u)/vocoder.sock
```