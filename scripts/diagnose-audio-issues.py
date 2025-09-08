#!/usr/bin/env python3
"""
Comprehensive audio debugging script for vocoder
Diagnoses common PulseAudio/ALSA/sounddevice issues
"""

import sounddevice as sd
import numpy as np
import subprocess
import sys
import os
import re
import time
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass

# ANSI color codes
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

def print_header(title: str):
    """Print a formatted header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{title:^60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")

def print_success(message: str):
    """Print success message"""
    print(f"{Colors.GREEN}✅ {message}{Colors.END}")

def print_error(message: str):
    """Print error message"""
    print(f"{Colors.RED}❌ {message}{Colors.END}")

def print_warning(message: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.END}")

def print_info(message: str):
    """Print info message"""
    print(f"{Colors.CYAN}ℹ️  {message}{Colors.END}")

def run_command(cmd: List[str], capture_output: bool = True, timeout: int = 10) -> Tuple[bool, str, str]:
    """Run a command and return success, stdout, stderr"""
    try:
        result = subprocess.run(cmd, capture_output=capture_output, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def check_system_audio():
    """Check basic system audio setup"""
    print_header("SYSTEM AUDIO DIAGNOSTICS")
    
    # Check PulseAudio
    print(f"{Colors.BOLD}1. PulseAudio Status:{Colors.END}")
    success, stdout, stderr = run_command(["pulseaudio", "--check"])
    if success:
        print_success("PulseAudio is running")
    else:
        print_error("PulseAudio not running")
        print_info("Try: pulseaudio -k && pulseaudio --start")
    
    # Check user audio group
    print(f"\n{Colors.BOLD}2. User Permissions:{Colors.END}")
    success, stdout, stderr = run_command(["groups"])
    if success and "audio" in stdout:
        print_success("User is in audio group")
    else:
        print_warning("User not in audio group")
        print_info("Add with: sudo usermod -a -G audio $USER")
    
    # Check sound cards
    print(f"\n{Colors.BOLD}3. Sound Cards:{Colors.END}")
    if os.path.exists("/proc/asound/cards"):
        with open("/proc/asound/cards", "r") as f:
            cards = f.read().strip()
        if cards:
            print_success("Sound cards found:")
            for line in cards.split('\n'):
                if line.strip():
                    print(f"    {line}")
        else:
            print_error("No sound cards found")
    else:
        print_error("/proc/asound/cards not found")

def check_pulseaudio_devices():
    """Check PulseAudio devices and configuration"""
    print_header("PULSEAUDIO DEVICE ANALYSIS")
    
    # List sources (inputs)
    print(f"{Colors.BOLD}1. Input Sources:{Colors.END}")
    success, stdout, stderr = run_command(["pactl", "list", "sources", "short"])
    if success:
        sources = []
        monitor_sources = []
        
        for line in stdout.strip().split('\n'):
            if line.strip():
                parts = line.split('\t')
                if len(parts) >= 2:
                    source_name = parts[1]
                    if "monitor" in source_name.lower():
                        monitor_sources.append(line)
                    else:
                        sources.append(line)
        
        print_success(f"Found {len(sources)} real input sources:")
        for source in sources:
            print(f"    {Colors.GREEN}• {source}{Colors.END}")
        
        if monitor_sources:
            print_warning(f"Found {len(monitor_sources)} monitor sources (avoid these):")
            for source in monitor_sources:
                print(f"    {Colors.YELLOW}• {source}{Colors.END}")
    else:
        print_error("Could not list PulseAudio sources")
    
    # Check current default source
    print(f"\n{Colors.BOLD}2. Default Source:{Colors.END}")
    success, stdout, stderr = run_command(["pactl", "info"])
    if success:
        for line in stdout.split('\n'):
            if "Default Source:" in line:
                default_source = line.split("Default Source:")[1].strip()
                if "monitor" in default_source.lower():
                    print_error(f"Default source is a MONITOR: {default_source}")
                    print_info("This will record system audio, not microphone!")
                else:
                    print_success(f"Default source looks good: {default_source}")
                break
        else:
            print_warning("Could not find default source information")
    
    # Check active recordings
    print(f"\n{Colors.BOLD}3. Active Recordings:{Colors.END}")
    success, stdout, stderr = run_command(["pactl", "list", "source-outputs"])
    if success and stdout.strip():
        print_info("Active recording streams found:")
        print(stdout)
    else:
        print_info("No active recording streams")

def check_sounddevice_setup():
    """Check sounddevice library setup"""
    print_header("PYTHON SOUNDDEVICE ANALYSIS")
    
    # Check if sounddevice can be imported
    print(f"{Colors.BOLD}1. Library Import:{Colors.END}")
    try:
        import sounddevice as sd
        print_success(f"sounddevice imported successfully (version: {sd.__version__})")
    except ImportError as e:
        print_error(f"Cannot import sounddevice: {e}")
        if "portaudio" in str(e).lower():
            print_info("Install PortAudio:")
            print_info("  Fedora: sudo dnf install portaudio portaudio-devel")
            print_info("  Ubuntu: sudo apt-get install portaudio19-dev")
        return False
    
    # List all devices
    print(f"\n{Colors.BOLD}2. Available Devices:{Colors.END}")
    try:
        devices = sd.query_devices()
        input_devices = []
        monitor_devices = []
        
        for i, device in enumerate(devices):
            if device['max_input_channels'] > 0:
                name_lower = device['name'].lower()
                is_monitor = any(pattern in name_lower for pattern in 
                               ['monitor', 'loopback', 'what u hear', 'stereo mix'])
                
                device_info = {
                    'id': i,
                    'name': device['name'],
                    'channels': device['max_input_channels'],
                    'sample_rate': device['default_samplerate'],
                    'is_monitor': is_monitor
                }
                
                if is_monitor:
                    monitor_devices.append(device_info)
                else:
                    input_devices.append(device_info)
        
        print_success(f"Found {len(input_devices)} real input devices:")
        for dev in input_devices:
            print(f"    {Colors.GREEN}• ID:{dev['id']:2d} - {dev['name']} "
                  f"({dev['channels']} ch, {dev['sample_rate']:.0f}Hz){Colors.END}")
        
        if monitor_devices:
            print_warning(f"Found {len(monitor_devices)} monitor devices (avoid these):")
            for dev in monitor_devices:
                print(f"    {Colors.YELLOW}• ID:{dev['id']:2d} - {dev['name']}{Colors.END}")
        
        return input_devices
        
    except Exception as e:
        print_error(f"Error querying devices: {e}")
        return []

def test_device_recording(device_id: int, device_name: str, duration: float = 3.0) -> Dict:
    """Test recording from a specific device"""
    print(f"\n{Colors.BOLD}Testing Device {device_id}: {device_name}{Colors.END}")
    print_info(f"Recording for {duration} seconds - SPEAK NOW!")
    
    result = {
        'success': False,
        'max_amplitude': 0.0,
        'rms': 0.0,
        'error': None,
        'samples': 0,
        'non_zero_percent': 0.0
    }
    
    try:
        # Record audio
        recording = sd.rec(
            int(duration * 16000),
            samplerate=16000,
            channels=1,
            device=device_id,
            dtype='float32'
        )
        
        # Show recording progress
        for i in range(int(duration)):
            print(f"  Recording... {i+1}/{int(duration)}")
            time.sleep(1)
        
        sd.wait()  # Wait for recording to complete
        
        # Analyze recording
        audio_data = recording.flatten()
        result['samples'] = len(audio_data)
        result['max_amplitude'] = float(np.max(np.abs(audio_data)))
        result['rms'] = float(np.sqrt(np.mean(audio_data**2)))
        result['non_zero_percent'] = (np.count_nonzero(audio_data) / len(audio_data)) * 100
        
        # Determine success
        if result['max_amplitude'] < 1e-6:
            print_error("Recording is completely silent")
            result['error'] = "Silent recording"
        elif result['max_amplitude'] < 0.001:
            print_warning(f"Very low input level: {result['max_amplitude']:.6f}")
            print_info("Consider increasing microphone gain")
            result['success'] = True
        elif result['max_amplitude'] > 0.95:
            print_warning(f"Input may be clipping: {result['max_amplitude']:.6f}")
            print_info("Consider reducing microphone gain")
            result['success'] = True
        else:
            print_success(f"Good recording level: {result['max_amplitude']:.6f}")
            result['success'] = True
        
        # Additional analysis
        print(f"    Max amplitude: {result['max_amplitude']:.6f}")
        print(f"    RMS level: {result['rms']:.6f}")
        print(f"    Non-zero samples: {result['non_zero_percent']:.1f}%")
        
        if result['non_zero_percent'] < 10:
            print_warning("Mostly silent recording - check microphone connection")
        
    except Exception as e:
        result['error'] = str(e)
        print_error(f"Recording failed: {e}")
    
    return result

def test_all_input_devices():
    """Test recording from all available input devices"""
    print_header("RECORDING TESTS")
    
    input_devices = check_sounddevice_setup()
    if not input_devices:
        print_error("No input devices available for testing")
        return
    
    working_devices = []
    
    for device in input_devices:
        result = test_device_recording(device['id'], device['name'])
        if result['success']:
            working_devices.append((device, result))
    
    print(f"\n{Colors.BOLD}Summary:{Colors.END}")
    if working_devices:
        print_success(f"Found {len(working_devices)} working devices:")
        for device, result in working_devices:
            quality = "Excellent" if result['max_amplitude'] > 0.1 else \
                     "Good" if result['max_amplitude'] > 0.01 else \
                     "Low" if result['max_amplitude'] > 0.001 else "Very Low"
            print(f"    • ID:{device['id']:2d} - {device['name']} "
                  f"({quality} - {result['max_amplitude']:.6f})")
    else:
        print_error("No working devices found!")
        print_info("Possible issues:")
        print_info("  - Microphone not connected/enabled")
        print_info("  - Recording from monitor instead of microphone")
        print_info("  - Microphone muted in system settings")
        print_info("  - Permission issues")

def provide_solutions():
    """Provide common solutions based on findings"""
    print_header("COMMON SOLUTIONS")
    
    print(f"{Colors.BOLD}If recording is silent:{Colors.END}")
    print("1. Open pavucontrol while recording to check input device")
    print("2. Ensure you're not selecting 'Monitor of...' devices")
    print("3. Check microphone mute status: pactl set-source-mute @DEFAULT_SOURCE@ false")
    print("4. Increase microphone gain in alsamixer or pavucontrol")
    
    print(f"\n{Colors.BOLD}If wrong device is being used:{Colors.END}")
    print("1. Set correct default: pactl set-default-source <SOURCE_NAME>")
    print("2. Use device ID in your application: sd.default.device = device_id")
    print("3. Check PulseAudio configuration in /etc/pulse/default.pa")
    
    print(f"\n{Colors.BOLD}If PortAudio/sounddevice issues:{Colors.END}")
    print("1. Install system PortAudio library:")
    print("   Fedora: sudo dnf install portaudio portaudio-devel")
    print("   Ubuntu: sudo apt-get install portaudio19-dev")
    print("2. Reinstall Python package: pip install --force-reinstall sounddevice")
    
    print(f"\n{Colors.BOLD}If PulseAudio issues:{Colors.END}")
    print("1. Restart PulseAudio: pulseaudio -k && pulseaudio --start")
    print("2. Check user in audio group: sudo usermod -a -G audio $USER")
    print("3. Check for conflicting audio systems (JACK, etc.)")

def run_system_audio_tests():
    """Run system-level audio tests"""
    print_header("SYSTEM AUDIO TESTS")
    
    # Test with arecord (ALSA)
    print(f"{Colors.BOLD}1. ALSA Test (arecord):{Colors.END}")
    test_file = "/tmp/test_alsa.wav"
    success, stdout, stderr = run_command(["timeout", "3", "arecord", "-f", "cd", test_file])
    
    if os.path.exists(test_file):
        size = os.path.getsize(test_file)
        print_success(f"ALSA recording created: {size} bytes")
        
        # Check if it has content
        success, stdout, stderr = run_command(["sox", test_file, "-n", "stat"])
        if success and "Maximum amplitude" in stderr:
            max_amp_line = [line for line in stderr.split('\n') if 'Maximum amplitude' in line]
            if max_amp_line:
                print_info(f"Audio content: {max_amp_line[0].strip()}")
        
        os.remove(test_file)
    else:
        print_error("ALSA recording failed")
        if stderr:
            print_error(f"Error: {stderr}")
    
    # Test with parec (PulseAudio)
    print(f"\n{Colors.BOLD}2. PulseAudio Test (parec):{Colors.END}")
    test_file = "/tmp/test_pulse.wav"
    cmd = ["timeout", "3", "parec", "--format=s16le", "--rate=16000", "--channels=1", test_file]
    success, stdout, stderr = run_command(cmd)
    
    if os.path.exists(test_file):
        size = os.path.getsize(test_file)
        print_success(f"PulseAudio recording created: {size} bytes")
        os.remove(test_file)
    else:
        print_error("PulseAudio recording failed")
        if stderr:
            print_error(f"Error: {stderr}")

def create_vocoder_test():
    """Create a test specifically for vocoder configuration"""
    print_header("VOCODER-SPECIFIC TEST")
    
    print_info("This test simulates vocoder's audio setup...")
    
    try:
        # Simulate vocoder's device selection
        devices = sd.query_devices()
        input_devices = []
        
        for i, device in enumerate(devices):
            if device['max_input_channels'] > 0:
                name_lower = device['name'].lower()
                is_monitor = any(pattern in name_lower for pattern in 
                               ['monitor', 'loopback', 'what u hear', 'stereo mix'])
                if not is_monitor:
                    input_devices.append((i, device))
        
        if not input_devices:
            print_error("No suitable input devices found for vocoder!")
            return
        
        # Find best device (similar to vocoder logic)
        best_device = None
        priority_keywords = ['microphone', 'mic', 'built-in', 'internal']
        
        for device_id, device in input_devices:
            name_lower = device['name'].lower()
            if any(keyword in name_lower for keyword in priority_keywords):
                best_device = (device_id, device)
                break
        
        if not best_device:
            best_device = input_devices[0]
        
        device_id, device = best_device
        print_success(f"Vocoder would select: {device['name']} (ID: {device_id})")
        
        # Test with vocoder-like parameters
        print_info("Testing with vocoder parameters (16kHz, 1 channel, 5s recording)...")
        
        recording = sd.rec(
            int(5 * 16000),
            samplerate=16000,
            channels=1,
            device=device_id,
            dtype='float32'
        )
        
        print_info("Recording 5 seconds - speak for vocoder test...")
        for i in range(5):
            print(f"  {i+1}/5 - Speak now!")
            time.sleep(1)
        
        sd.wait()
        
        # Apply vocoder-like gain (15dB boost)
        gain_multiplier = 10 ** (15.0 / 20.0)  # 15dB gain
        audio_data = recording.flatten() * gain_multiplier
        audio_data = np.clip(audio_data, -1.0, 1.0)
        
        # Analyze
        max_amp = np.max(np.abs(audio_data))
        rms = np.sqrt(np.mean(audio_data**2))
        
        print_success(f"Vocoder test complete:")
        print(f"    Raw amplitude: {np.max(np.abs(recording)):.6f}")
        print(f"    After +15dB gain: {max_amp:.6f}")
        print(f"    RMS level: {rms:.6f}")
        
        if max_amp > 0.01:
            print_success("Vocoder should work well with this setup!")
        elif max_amp > 0.001:
            print_warning("Vocoder might work but may need more gain")
        else:
            print_error("Vocoder likely won't work - too quiet or silent")
            
    except Exception as e:
        print_error(f"Vocoder test failed: {e}")

def main():
    """Main diagnostic routine"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║              VOCODER AUDIO DIAGNOSTICS                  ║")
    print("║          Comprehensive Audio Issue Detection             ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"{Colors.END}")
    
    # Check if numpy is available
    try:
        import numpy as np
    except ImportError:
        print_error("NumPy not available - some tests will be skipped")
        print_info("Install with: pip install numpy")
        return
    
    # Run all diagnostics
    check_system_audio()
    check_pulseaudio_devices()
    
    input_devices = check_sounddevice_setup()
    if input_devices:
        run_system_audio_tests()
        test_all_input_devices()
        create_vocoder_test()
    
    provide_solutions()
    
    print(f"\n{Colors.BOLD}{Colors.GREEN}Diagnostics complete!{Colors.END}")
    print_info("Check the results above to identify and fix audio issues.")
    print_info("For detailed solutions, see: docs/audio-debugging-guide.md")

if __name__ == "__main__":
    main()