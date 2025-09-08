name: "Vocoder Documentation Update and Dockerization"
description: |
  Comprehensive PRP for updating all vocoder documentation to reflect the current implementation 
  and dockerizing the vocoder daemon for portable deployment while maintaining host system integration.

---

## Goal

**Feature Goal**: Update all documentation to reflect current vocoder implementation and create a fully containerized vocoder daemon that integrates with host audio, Whisper API, and desktop environment.

**Deliverable**: 
- Corrected documentation files (README.md, COMMANDS.md, config files)
- Dockerfile and docker-compose.yml for vocoder daemon
- Docker run scripts with proper host integration
- Updated installation and deployment documentation

**Success Definition**: 
- All documentation accurately reflects current implementation (port 8771, clipboard mode, etc.)
- Vocoder runs successfully in Docker container with full functionality
- Container can record audio, transcribe via host Whisper API, and type/copy text
- One-command deployment with docker-compose

## User Persona

**Target User**: DevOps engineer or developer deploying vocoder

**Use Case**: Deploy vocoder as a containerized service while maintaining integration with host system services (Whisper API, audio, desktop)

**User Journey**: 
1. Clone vocoder repository
2. Run `docker-compose up` 
3. Vocoder daemon starts with proper host integration
4. User presses hotkey, speaks, gets transcribed text

**Pain Points Addressed**: 
- Complex dependency installation
- Version conflicts with system Python
- Portable deployment across Linux distributions
- Consistent environment for debugging

## Why

- **Documentation Accuracy**: Current docs reference wrong ports (8767 vs 8771), missing features (clipboard mode), outdated configuration
- **Deployment Simplification**: Docker eliminates complex dependency management
- **Portability**: Run on any Linux system with Docker installed
- **Development Consistency**: Same environment for all developers
- **Security Isolation**: Container provides security boundary while maintaining necessary host access

## What

### Documentation Updates Required

1. **Port Number Corrections**: Update all references from 8767/8765 to 8771
2. **New Features Documentation**: Document CLIPBOARD_MODE, DEBUG, MAX_DURATION environment variables
3. **Configuration Alignment**: Fix config/vocoder.yaml parameters to match code
4. **Model References**: Update from "medium" to "small" model references
5. **Hotkey Corrections**: Ensure all docs show Super+Space consistently

### Docker Implementation Requirements

1. **Audio Access**: PulseAudio socket sharing for recording
2. **Network Access**: Bridge network with host.docker.internal for Whisper API
3. **Input Injection**: /dev/uinput device access for ydotool
4. **Clipboard Integration**: Wayland socket for wl-copy
5. **Notifications**: D-Bus socket for notify-send

### Success Criteria

- [ ] All port numbers consistently reference 8771
- [ ] CLIPBOARD_MODE environment variable documented
- [ ] Docker container successfully records audio
- [ ] Container connects to host Whisper API on port 8771
- [ ] Text typing/clipboard functionality works from container
- [ ] Desktop notifications appear from container

## All Needed Context

### Context Completeness Check

_This PRP contains all file paths, specific line numbers, Docker mounting requirements, and security considerations needed for implementation._

### Documentation & References

```yaml
# Critical Docker References
- url: https://github.com/mviereck/x11docker/wiki/Container-sound:-ALSA-or-Pulseaudio
  why: Comprehensive guide for PulseAudio socket sharing in containers
  critical: Must use socket sharing, not device mounting, to avoid blocking host audio

- url: https://github.com/ivangtorre/docker-pulseaudio-micro-record
  why: Working example of Python audio recording in Docker
  pattern: PulseAudio environment variables and volume mounts

- file: /home/ice/dev/vocoder/bin/vocoder
  why: Main daemon implementation to containerize
  pattern: Lines 42-52 for Config dataclass with environment variables
  gotcha: Line 255 uses 'small' model, not 'tiny' as some docs claim

- file: /home/ice/.config/systemd/user/vocoder.service
  why: Current systemd service configuration showing environment variables
  pattern: Lines 18-22 for environment variable configuration
  gotcha: Contains comment fragments that break parsing

# Files Requiring Documentation Updates
- file: /home/ice/dev/vocoder/README.md
  lines: [55, 96, 120]
  issue: References port 8767 instead of 8771

- file: /home/ice/dev/vocoder/COMMANDS.md
  lines: [87, 112, 205, 295]
  issue: References ports 8765 and 8767 instead of 8771

- file: /home/ice/dev/vocoder/config/vocoder.yaml
  line: 5
  issue: Wrong port (8767) and parameter names
```

### Current Codebase tree

```bash
/home/ice/dev/vocoder/
├── bin/
│   ├── vocoder                    # Main daemon (Python, 628 lines)
│   └── vocoderctl                 # Control client (Python)
├── config/
│   └── vocoder.yaml              # Configuration file (needs updates)
├── daemon/
│   └── vocoder.service           # Systemd template
├── scripts/
│   ├── whisper-dictate.sh       # Option A script
│   ├── diagnose-audio-issues.py # Audio diagnostics
│   └── [various setup scripts]
├── docs/
│   └── audio-quick-fixes.md
├── PRPs/
│   ├── vocoder-debugging-fix.md
│   └── templates/
└── README.md, COMMANDS.md
```

### Desired Codebase tree with files to be added

```bash
/home/ice/dev/vocoder/
├── docker/                        # NEW: Docker configuration
│   ├── Dockerfile                # Multi-stage Python 3.11 image
│   ├── docker-compose.yml       # Complete service definition
│   ├── run-vocoder.sh          # Host integration script
│   └── .env.example             # Environment variables template
├── bin/
│   ├── vocoder                  # Unchanged (main daemon)
│   └── vocoderctl               # Unchanged (control client)
├── config/
│   └── vocoder.yaml             # UPDATED: Correct port and parameters
├── docs/
│   ├── DOCKER.md                # NEW: Docker deployment guide
│   └── audio-quick-fixes.md    # UPDATED: Correct port references
├── README.md                     # UPDATED: Accurate documentation
├── COMMANDS.md                   # UPDATED: Correct ports and examples
└── requirements.txt              # NEW: Consolidated Python dependencies
```

### Known Gotchas of our codebase & Library Quirks

```python
# CRITICAL: sounddevice requires PortAudio which needs specific ALSA configuration
# The container must run with same UID as host user for PulseAudio authentication

# CRITICAL: wl-copy hangs without timeout - fixed in code with asyncio.wait_for()
# Line 391-394 in bin/vocoder has 2-second timeout

# CRITICAL: ydotool requires /dev/uinput device access
# Container needs --device /dev/uinput or will fail silently

# CRITICAL: Port 8771 is hardcoded in multiple places
# Environment variable WHISPER_URL must include full URL with port

# CRITICAL: Whisper model is 'small' (line 255) not 'tiny' or 'medium'
# Documentation claiming otherwise is incorrect
```

## Implementation Blueprint

### Data models and structure

No new data models required - this is infrastructure and documentation work.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: UPDATE config/vocoder.yaml
  - CHANGE: Line 5 from port 8767 to 8771
  - CHANGE: Line 17 from "amplitude: 0.02" to "silence_threshold: 0.01"
  - CHANGE: Socket path to use dynamic UID
  - FOLLOW: Current bin/vocoder Config dataclass (lines 42-52)

Task 2: UPDATE Documentation Files (Port Corrections)
  - MODIFY: README.md lines [55, 96, 120] - change 8767 to 8771
  - MODIFY: COMMANDS.md lines [87, 112, 205, 295] - change 8765/8767 to 8771
  - MODIFY: docs/audio-quick-fixes.md - search and replace all port references
  - ADD: Documentation for CLIPBOARD_MODE environment variable
  - ADD: Documentation for MAX_DURATION environment variable

Task 3: CREATE requirements.txt
  - EXTRACT: Python dependencies from bin/vocoder imports
  - INCLUDE: numpy>=1.24.0, sounddevice>=0.5.0, httpx>=0.24.0
  - OPTIONAL: systemd-python>=235 (mark as optional)
  - REFERENCE: requirements-optionb.txt if exists

Task 4: CREATE docker/Dockerfile
  - BASE: python:3.11-slim for minimal size
  - INSTALL: System dependencies (pulseaudio, portaudio19-dev, ydotool, wl-clipboard)
  - USER: Create app user with dynamic UID/GID matching host
  - COPY: bin/vocoder and requirements.txt
  - WORKDIR: /app
  - CMD: ["python", "bin/vocoder"]

Task 5: CREATE docker/docker-compose.yml
  - SERVICE: vocoder with build context
  - NETWORK: bridge with host.docker.internal
  - DEVICES: /dev/snd, /dev/uinput
  - VOLUMES: PulseAudio socket, Wayland socket, D-Bus socket
  - ENVIRONMENT: All required variables including WHISPER_URL
  - USER: "${USER_ID:-1000}:${GROUP_ID:-1000}"

Task 6: CREATE docker/run-vocoder.sh
  - CAPTURE: User ID and group ID
  - MOUNT: All required sockets and devices
  - ENVIRONMENT: Pass through display and audio variables
  - NETWORK: Bridge with host.docker.internal mapping
  - EXECUTE: docker run with all parameters

Task 7: CREATE docker/.env.example
  - TEMPLATE: All configurable environment variables
  - DEFAULTS: WHISPER_URL=http://host.docker.internal:8771/v1/transcribe
  - OPTIONS: CLIPBOARD_MODE, MAX_DURATION, DEBUG
  - SYSTEM: USER_ID, GROUP_ID auto-detection

Task 8: CREATE docs/DOCKER.md
  - QUICKSTART: docker-compose up instructions
  - REQUIREMENTS: Docker, Docker Compose, host Whisper API
  - TROUBLESHOOTING: Common audio, permission, network issues
  - CONFIGURATION: Environment variable reference

Task 9: UPDATE README.md
  - ADD: Docker deployment section
  - CORRECT: All port references to 8771
  - DOCUMENT: CLIPBOARD_MODE feature
  - CLARIFY: Difference between Option A and B
  - UPDATE: Model reference to 'small'

Task 10: UPDATE COMMANDS.md
  - CORRECT: All port numbers and URLs
  - UPDATE: Line number references for configuration
  - ADD: Docker-specific commands section
  - DOCUMENT: New environment variables
```

### Docker Implementation Details

```dockerfile
# docker/Dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Audio support
    pulseaudio pulseaudio-utils libpulse0 alsa-utils \
    portaudio19-dev \
    # Input/GUI support  
    ydotool wtype \
    # Clipboard
    wl-clipboard xclip \
    # Notifications
    libnotify-bin dbus \
    # Utilities
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user with configurable UID/GID
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g $GROUP_ID app && \
    useradd -m -u $USER_ID -g app app && \
    usermod -a -G audio app

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY bin/ ./bin/
COPY config/ ./config/

# Switch to app user
USER app

# Run vocoder daemon
CMD ["python", "bin/vocoder"]
```

```yaml
# docker/docker-compose.yml
version: '3.8'

services:
  vocoder:
    build: 
      context: ..
      dockerfile: docker/Dockerfile
      args:
        USER_ID: ${USER_ID:-1000}
        GROUP_ID: ${GROUP_ID:-1000}
    
    network_mode: "bridge"
    
    environment:
      # Audio configuration
      - PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native
      - PULSE_COOKIE=${HOME}/.config/pulse/cookie
      
      # Display configuration
      - DISPLAY=${DISPLAY}
      - WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
      - XDG_RUNTIME_DIR=/tmp
      
      # Notifications
      - DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS}
      
      # Vocoder configuration
      - WHISPER_URL=http://host.docker.internal:8771/v1/transcribe
      - CLIPBOARD_MODE=${CLIPBOARD_MODE:-true}
      - MAX_DURATION=${MAX_DURATION:-60}
      - DEBUG=${DEBUG:-1}
    
    devices:
      - /dev/snd:/dev/snd
      - /dev/uinput:/dev/uinput
    
    volumes:
      # Audio access
      - ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native
      - ${HOME}/.config/pulse/cookie:/home/app/.config/pulse/cookie:ro
      
      # Display access
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
      - ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:/tmp/${WAYLAND_DISPLAY}
      
      # Notifications
      - /run/user/${USER_ID}/bus:/run/user/${USER_ID}/bus
      
      # Application socket
      - /run/user/${USER_ID}:/run/user/${USER_ID}
    
    extra_hosts:
      - "host.docker.internal:host-gateway"
    
    user: "${USER_ID:-1000}:${GROUP_ID:-1000}"
    
    restart: unless-stopped
```

### Integration Points

```yaml
CONFIGURATION:
  - file: config/vocoder.yaml
  - changes: Port 8771, correct parameter names
  
ENVIRONMENT:
  - file: docker/.env
  - variables: USER_ID, GROUP_ID, WHISPER_URL, CLIPBOARD_MODE
  
DOCUMENTATION:
  - files: README.md, COMMANDS.md, docs/DOCKER.md
  - updates: Port corrections, feature documentation, Docker instructions
```

## Validation Loop

### Level 1: Documentation Validation

```bash
# Verify all port references are correct
grep -r "8767\|8765" . --include="*.md" --include="*.yaml" --include="*.yml"
# Expected: No results (all should be 8771)

# Verify CLIPBOARD_MODE is documented
grep -r "CLIPBOARD_MODE" README.md COMMANDS.md docs/
# Expected: Multiple hits showing documentation

# Check for broken line number references
grep -n "line [0-9]" COMMANDS.md | head -10
# Expected: Line numbers should match actual code
```

### Level 2: Docker Build Validation

```bash
# Build Docker image
cd docker && docker build -t vocoder:test ..
# Expected: Successful build with no errors

# Verify image contents
docker run --rm vocoder:test ls -la /app/bin/
# Expected: vocoder and vocoderctl present

# Check Python dependencies
docker run --rm vocoder:test pip list
# Expected: numpy, sounddevice, httpx installed
```

### Level 3: Container Runtime Validation

```bash
# Start container with minimal config
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
docker-compose up -d

# Check container is running
docker-compose ps
# Expected: vocoder service "Up"

# Check container logs
docker-compose logs vocoder | tail -20
# Expected: "Starting vocoder daemon" message

# Test socket connection
python3 bin/vocoderctl status
# Expected: Shows daemon status

# Test audio device access
docker-compose exec vocoder python -c "import sounddevice as sd; print(sd.query_devices())"
# Expected: Lists audio devices including non-monitor inputs
```

### Level 4: Full Integration Testing

```bash
# Test with actual recording (requires microphone)
python3 bin/vocoderctl toggle
sleep 3  # Speak during this time
python3 bin/vocoderctl toggle
# Expected: Notification appears, text in clipboard

# Verify Whisper API connectivity
docker-compose exec vocoder curl -s http://host.docker.internal:8771/health
# Expected: JSON health response

# Test clipboard functionality
docker-compose exec vocoder sh -c 'echo "test" | wl-copy'
wl-paste
# Expected: "test" output

# Clean shutdown test
docker-compose down
# Expected: Clean shutdown with no errors
```

## Final Validation Checklist

### Documentation Validation

- [ ] All port numbers updated to 8771
- [ ] CLIPBOARD_MODE environment variable documented
- [ ] MAX_DURATION environment variable documented  
- [ ] Model references updated to 'small'
- [ ] Hotkey consistently documented as Super+Space
- [ ] Docker deployment instructions added

### Docker Implementation Validation

- [ ] Dockerfile builds successfully
- [ ] docker-compose.yml starts service
- [ ] Audio recording works from container
- [ ] Whisper API connection succeeds
- [ ] Clipboard/typing functionality works
- [ ] Notifications appear on desktop

### Integration Validation

- [ ] Container can be controlled via vocoderctl
- [ ] Hotkey triggers recording in container
- [ ] Transcribed text appears in clipboard
- [ ] Container restarts cleanly
- [ ] Logs are accessible and informative

### Security Validation

- [ ] Container runs as non-root user
- [ ] Only required devices are mounted
- [ ] No --privileged flag used
- [ ] Sockets mounted read-only where appropriate

---

## Anti-Patterns to Avoid

- ❌ Don't use --privileged flag for container
- ❌ Don't mount entire /dev directory
- ❌ Don't hardcode user IDs in Dockerfile
- ❌ Don't use host networking when bridge works
- ❌ Don't skip timeout on wl-copy operations
- ❌ Don't assume ydotool has root privileges

## Confidence Score

**9/10** - High confidence in successful implementation

This PRP provides comprehensive context including:
- Specific line numbers for all documentation updates
- Complete Docker configuration with tested patterns
- Host integration requirements from research
- Security considerations and anti-patterns
- Multi-level validation procedures

The only uncertainty (1 point deduction) is potential variation in host system configurations that may require minor adjustments to socket paths or device permissions.