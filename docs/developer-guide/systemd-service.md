# systemd Service Documentation

Complete guide for the Vocoder systemd service configuration and management.

## Service File Overview

Location: `daemon/vocoder.service`

```ini
[Unit]
Description=Vocoder Daemon - Fast voice dictation (Option B)
Documentation=https://github.com/arealicehole/vocoder
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=notify
ExecStart=/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder
Restart=always
RestartSec=5

# Environment
Environment="PYTHONUNBUFFERED=1"
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="WHISPER_URL=http://127.0.0.1:8771/v1/transcribe"

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
MemoryLimit=500M
CPUQuota=50%

# Watchdog
WatchdogSec=30

[Install]
WantedBy=default.target
```

## Unit Section

### Dependencies

```ini
After=graphical-session.target
Wants=graphical-session.target
```

- **After**: Ensures GUI is available before starting
- **Wants**: Soft dependency - continues if target unavailable

### Additional Dependencies (Optional)

```ini
# Network dependency
After=network-online.target
Wants=network-online.target

# Audio system dependency
After=sound.target
Requires=sound.target

# Specific service dependency
After=whisper-api.service
```

## Service Section

### Service Type

```ini
Type=notify
```

- **notify**: Service sends ready notification via sd_notify()
- Alternatives:
  - `simple`: Process doesn't fork (default)
  - `forking`: Traditional daemon
  - `oneshot`: Runs once and exits
  - `idle`: Delayed until all jobs finish

### Process Management

```ini
ExecStart=/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
```

### Restart Policy

```ini
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3
```

- **Restart**: When to restart (always, on-failure, on-abnormal)
- **RestartSec**: Delay between restarts
- **StartLimitIntervalSec**: Time window for burst limit
- **StartLimitBurst**: Max restarts in time window

### Environment Variables

```ini
Environment="PYTHONUNBUFFERED=1"
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="WHISPER_URL=http://127.0.0.1:8771/v1/transcribe"
```

Variables available:
- `%U`: User UID
- `%u`: Username
- `%h`: User home directory
- `%t`: Runtime directory

### Resource Limits

```ini
# Memory
MemoryLimit=500M
MemorySwapMax=0

# CPU
CPUQuota=50%
CPUWeight=100

# IO
IOWeight=100
IOReadBandwidthMax=/dev/sda 10M
IOWriteBandwidthMax=/dev/sda 5M

# Tasks
TasksMax=64
```

### Security Hardening

```ini
# Basic security
NoNewPrivileges=true
PrivateTmp=true

# Advanced hardening
ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true

# Filesystem access
ReadWritePaths=/run/user/%U
ReadOnlyPaths=/home/%u/dev/vocoder
PrivateDevices=true
```

### Watchdog

```ini
WatchdogSec=30
```

Service must call `sd_notify("WATCHDOG=1")` periodically.

Python implementation:
```python
import systemd.daemon
import threading

def watchdog_ping():
    while running:
        systemd.daemon.notify("WATCHDOG=1")
        time.sleep(10)  # Ping every 10s for 30s timeout

if systemd.daemon.booted():
    threading.Thread(target=watchdog_ping, daemon=True).start()
    systemd.daemon.notify("READY=1")
```

## Installation Section

```ini
[Install]
WantedBy=default.target
```

- **default.target**: User's default target
- **graphical-session.target**: GUI session
- **multi-user.target**: System-wide

## Service Management

### Installation

```bash
# Copy service file
cp daemon/vocoder.service ~/.config/systemd/user/

# Or symlink for development
ln -s $(pwd)/daemon/vocoder.service ~/.config/systemd/user/

# Reload systemd
systemctl --user daemon-reload
```

### Basic Commands

```bash
# Enable (auto-start)
systemctl --user enable vocoder.service

# Start
systemctl --user start vocoder.service

# Stop
systemctl --user stop vocoder.service

# Restart
systemctl --user restart vocoder.service

# Status
systemctl --user status vocoder.service

# Disable
systemctl --user disable vocoder.service
```

### Debugging

```bash
# View logs
journalctl --user -u vocoder -n 50
journalctl --user -u vocoder -f  # Follow
journalctl --user -u vocoder --since "5 min ago"

# Verify service file
systemd-analyze verify daemon/vocoder.service

# Check dependencies
systemctl --user list-dependencies vocoder.service

# Environment
systemctl --user show-environment
```

## Service States

### Normal States

- **inactive**: Not running
- **activating**: Starting up
- **active**: Running normally
- **deactivating**: Shutting down

### Error States

- **failed**: Exited with error
- **auto-restart**: Waiting to restart
- **not-found**: Service file missing

### Check State

```bash
systemctl --user is-active vocoder.service
systemctl --user is-enabled vocoder.service
systemctl --user is-failed vocoder.service
```

## Logging

### Log Levels

```python
import logging
import systemd.journal

# Configure logging to systemd
handler = systemd.journal.JournalHandler()
handler.setFormatter(logging.Formatter('%(message)s'))
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Log with priority
logger.info("Service started")
logger.warning("Low memory")
logger.error("Connection failed")
```

### Structured Logging

```python
import systemd.journal

systemd.journal.send(
    "Service started",
    PRIORITY=6,  # Info
    CODE_FILE=__file__,
    CODE_LINE=42,
    CODE_FUNC="main",
    CUSTOM_FIELD="value"
)
```

### Query Logs

```bash
# By priority
journalctl --user -u vocoder -p err  # Errors only
journalctl --user -u vocoder -p warning  # Warnings and above

# By time
journalctl --user -u vocoder --since today
journalctl --user -u vocoder --since "2024-01-01" --until "2024-01-02"

# Export formats
journalctl --user -u vocoder -o json
journalctl --user -u vocoder -o cat  # Message only
```

## Development Tips

### Testing Service

```bash
# Run directly (not as service)
/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder

# Run with service environment
systemd-run --uid=$USER --gid=$USER --setenv=WHISPER_URL=http://127.0.0.1:8771/v1/transcribe /usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder
```

### Override Settings

Create override file: `~/.config/systemd/user/vocoder.service.d/override.conf`

```ini
[Service]
Environment="DEBUG=1"
MemoryLimit=1G
```

Apply overrides:
```bash
systemctl --user daemon-reload
systemctl --user restart vocoder.service
```

### Template Service

For multiple instances: `vocoder@.service`

```ini
[Service]
ExecStart=/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder --config %i
```

Use:
```bash
systemctl --user start vocoder@production.service
systemctl --user start vocoder@development.service
```

## Common Issues

### Service Won't Start

```bash
# Check syntax
systemd-analyze verify daemon/vocoder.service

# Check permissions
ls -la /home/ice/dev/vocoder/bin/vocoder

# Check Python
/usr/bin/python3 --version

# Manual test
/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder
```

### Service Keeps Restarting

```bash
# Check restart limit
systemctl --user show vocoder.service | grep -i restart

# Reset failure state
systemctl --user reset-failed vocoder.service

# Increase restart delay
# Edit service: RestartSec=10
```

### High Resource Usage

```bash
# Check current usage
systemctl --user status vocoder.service

# Monitor resources
systemd-cgtop

# Adjust limits in service file
CPUQuota=30%
MemoryLimit=200M
```

### Socket Issues

```bash
# Check socket
ls -la /run/user/$(id -u)/vocoder.sock

# Socket permissions
chmod 600 /run/user/$(id -u)/vocoder.sock

# Clean stale socket
rm -f /run/user/$(id -u)/vocoder.sock
systemctl --user restart vocoder.service
```

## Best Practices

### Service Design

1. **Graceful Shutdown**: Handle SIGTERM properly
2. **Status Updates**: Use sd_notify() for state changes
3. **Logging**: Use systemd journal for all logging
4. **Configuration**: Support environment variables
5. **Socket Activation**: Consider socket activation for on-demand start

### Python Integration

```python
#!/usr/bin/env python3
import signal
import sys
import systemd.daemon

class VocoderDaemon:
    def __init__(self):
        self.running = True
        signal.signal(signal.SIGTERM, self.handle_shutdown)
        signal.signal(signal.SIGINT, self.handle_shutdown)
    
    def handle_shutdown(self, signum, frame):
        self.running = False
        systemd.daemon.notify("STOPPING=1")
    
    def run(self):
        # Notify systemd we're ready
        systemd.daemon.notify("READY=1")
        
        while self.running:
            # Main loop
            systemd.daemon.notify("WATCHDOG=1")
            # ... do work ...
        
        # Clean shutdown
        systemd.daemon.notify("STATUS=Shutting down...")

if __name__ == "__main__":
    daemon = VocoderDaemon()
    daemon.run()
```

### Monitoring

```bash
# Create monitoring script
#!/bin/bash
systemctl --user is-active vocoder.service || \
  systemctl --user restart vocoder.service

# Add to crontab
*/5 * * * * /home/ice/dev/vocoder/scripts/monitor-service.sh
```