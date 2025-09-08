# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation structure with user and developer guides
- Standard project files (LICENSE, CHANGELOG, CONTRIBUTING)
- Consistent port configuration (8771) across all components

### Changed
- Restructured documentation into user-guide and developer-guide directories
- Streamlined README.md to focus on quick start and overview
- Standardized port to 8771 across all configuration files

### Removed
- Development artifacts and test files
- Duplicate Option A/B documentation
- Outdated systemd directory (duplicate of daemon/)
- Unused GUI directory

## [1.0.0] - 2024-01-01

### Added
- Initial release with dual-mode operation (Option A script and Option B daemon)
- Push-to-talk voice dictation with Whisper API integration
- Wayland support via ydotool
- Automatic silence detection
- Clipboard fallback mechanism
- systemd service integration for daemon mode
- Comprehensive debugging tools

### Features
- Sub-50ms response time in daemon mode
- Configurable audio gain for different microphones
- Support for multiple Whisper models (tiny, base, small, medium, large)
- Real-time transcription with automatic typing

[Unreleased]: https://github.com/arealicehole/vocoder/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/arealicehole/vocoder/releases/tag/v1.0.0