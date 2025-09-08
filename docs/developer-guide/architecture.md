# Architecture Overview

Technical architecture and design decisions for the Vocoder project.

## System Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│   User Input    │────▶│   Vocoder    │────▶│  Whisper    │
│  (Super+Space)  │     │   Process    │     │     API     │
└─────────────────┘     └──────────────┘     └─────────────┘
                               │                     │
                               ▼                     ▼
                        ┌──────────────┐     ┌─────────────┐
                        │    Audio     │     │   Text      │
                        │   Capture    │     │   Output    │
                        └──────────────┘     └─────────────┘
                               │                     │
                               ▼                     ▼
                        ┌──────────────┐     ┌─────────────┐
                        │  PulseAudio/ │     │   ydotool/  │
                        │     ALSA     │     │    wtype    │
                        └──────────────┘     └─────────────┘
```

## Dual-Mode Design

### Option A: Script Mode

Simple bash script architecture for reliability:

```bash
whisper-dictate.sh
├── Audio Recording (sox/rec)
├── Silence Detection
├── API Call (curl)
├── JSON Parsing (jq)
└── Text Injection (ydotool)
```

**Advantages:**
- Simple to debug
- No persistent processes
- Minimal dependencies
- Easy to modify

**Trade-offs:**
- 1-2 second startup time
- New process per invocation

### Option B: Daemon Mode

Persistent daemon with IPC for instant response:

```
vocoder (daemon)
├── Persistent Process
├── Socket Listener (/run/user/1000/vocoder.sock)
├── Audio Stream Handler
├── Whisper Connection Pool
└── systemd Integration

vocoderctl (client)
├── Socket Connection
├── Command Protocol
└── Status Reporting
```

**Advantages:**
- <50ms response time
- Reusable connections
- Advanced features (toggle mode)
- systemd management

**Trade-offs:**
- More complex
- Memory usage (~50MB)
- Requires service management

## Component Details

### Audio Pipeline

```python
# Audio flow
1. PulseAudio Source → 
2. sounddevice capture →
3. NumPy buffer →
4. Silence detection →
5. Audio trimming →
6. WAV encoding →
7. HTTP multipart upload
```

### Silence Detection Algorithm

```python
def detect_silence(audio_chunk, threshold=0.02):
    """
    Sliding window approach:
    - Start: 0.5s of audio > threshold
    - Stop: 2.0s of audio < threshold
    - Max duration: 30s safety limit
    """
    amplitude = np.abs(audio_chunk).mean()
    return amplitude < threshold
```

### IPC Protocol (Option B)

Unix domain socket with JSON messages:

```json
// Client → Daemon
{
  "command": "start|stop|toggle|status|shutdown",
  "timestamp": 1234567890
}

// Daemon → Client
{
  "status": "idle|recording|processing",
  "message": "Recording started",
  "error": null
}
```

## Data Flow

### Recording Flow

1. **Trigger**: Hotkey press (Super+Space)
2. **Capture**: 16kHz mono audio stream
3. **Processing**: Apply gain (15dB for DJI MIC)
4. **Detection**: Monitor for silence
5. **Termination**: Stop on 2s silence or 30s max

### Transcription Flow

1. **Encoding**: Convert to WAV format
2. **Upload**: Multipart POST to Whisper API
3. **Model**: Process with selected model (tiny default)
4. **Response**: Parse JSON response
5. **Extraction**: Get transcript text

### Output Flow

1. **Primary**: Type via ydotool/wtype
2. **Fallback**: Copy to clipboard
3. **Notification**: User feedback

## Technology Stack

### Core Technologies

- **Language**: Python 3.9+ (daemon), Bash (scripts)
- **Audio**: PulseAudio/ALSA via sounddevice
- **IPC**: Unix domain sockets
- **Service**: systemd user services
- **Config**: YAML configuration

### Dependencies

```python
# Python Dependencies
numpy==1.24.4        # Audio processing
sounddevice==0.4.6   # Audio capture
httpx==0.24.1        # Async HTTP client

# System Dependencies
sox          # Audio recording (Option A)
ydotool      # Wayland typing
portaudio    # Audio library
```

## Design Decisions

### Why Two Modes?

- **Flexibility**: Users choose complexity vs performance
- **Fallback**: Script mode as reliable backup
- **Learning Curve**: Simple option for beginners

### Why Unix Sockets?

- **Performance**: Faster than network sockets
- **Security**: User-scoped, no network exposure
- **Simplicity**: No port management

### Why systemd?

- **Management**: Automatic start/restart
- **Logging**: Integrated with journald
- **Resources**: CPU/memory limits
- **User-scope**: No root required

## Security Considerations

### Isolation

- User-scoped services (no root)
- Local-only sockets
- No network exposure by default

### Audio Privacy

- No persistent recording storage
- Temporary files in user runtime dir
- Automatic cleanup

### API Security

- Localhost-only by default
- Optional API key support
- HTTPS for remote servers

## Performance Characteristics

### Memory Usage

- **Option A**: ~10MB per invocation
- **Option B**: ~50MB persistent

### Response Times

- **Option A**: 1-2s startup + processing
- **Option B**: <50ms startup + processing

### CPU Usage

- **Idle**: <1%
- **Recording**: 5-10%
- **Processing**: 15-25%

## Extension Points

### Custom Audio Sources

```python
class CustomAudioSource:
    def get_device_id(self):
        # Return specific device ID
        
    def apply_filters(self, audio):
        # Custom audio processing
```

### Alternative Transcription

```python
class TranscriptionProvider:
    def transcribe(self, audio_data):
        # Implement API call
        # Return transcript text
```

### Output Handlers

```python
class OutputHandler:
    def handle(self, text):
        # Custom text handling
        # E.g., commands, macros
```

## Development Workflow

### Local Development

```bash
# Test without installation
python3 bin/vocoder

# Debug mode
PYTHONUNBUFFERED=1 python3 bin/vocoder

# Test client
python3 bin/vocoderctl toggle
```

### Service Development

```bash
# Test service file
systemd-analyze verify daemon/vocoder.service

# Run in foreground
/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder

# Monitor logs
journalctl --user -u vocoder -f
```

## Future Considerations

### Planned Improvements

- WebSocket support for real-time streaming
- Multi-language auto-detection
- Voice commands recognition
- Custom wake words
- GPU acceleration support

### Scalability

- Connection pooling for multiple users
- Distributed Whisper instances
- Load balancing support
- Metrics and monitoring

## Code Organization

```
vocoder/
├── bin/
│   ├── vocoder       # Main daemon (Python)
│   └── vocoderctl    # Control client (Python)
├── config/
│   └── vocoder.yaml  # Configuration
├── daemon/
│   └── vocoder.service  # systemd unit
└── scripts/
    ├── whisper-dictate.sh  # Option A implementation
    └── *.sh              # Helper scripts
```

## Testing Strategy

### Unit Testing

- Audio processing functions
- Silence detection algorithm
- Configuration parsing

### Integration Testing

- Whisper API communication
- Socket communication
- systemd integration

### End-to-End Testing

- Full recording → transcription → output
- Hotkey triggering
- Error scenarios