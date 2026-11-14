# Security Policy

## Supported Versions

We provide security updates for the latest stable release of **Novastar Picture Manager**.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## 🔒 Privacy & Local-First Architecture

Novastar Picture Manager is built as a **local-first, privacy-respecting** utility:
- **Zero Remote Telemetry**: The application does not collect, track, or phone home with usage telemetry or file metadata.
- **No Remote Image Uploads**: All decoding, cropping, rendering, and encoding happens entirely within your local CPU/GPU memory.
- **Preservation of Originals**: The application preserves original media on disk and prevents silent overwrites by default.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or exploit within Novastar Picture Manager, please **do not report it in public GitHub issues**.

Instead, please send a report to our security maintainers:

- **Email**: `security@novastar.org`
- Include:
  - Description of the vulnerability.
  - Steps to reproduce or proof-of-concept (PoC).
  - Potential impact on the host system or user privacy.
  - The operating system and Flutter version tested.

We will acknowledge receipt within 48 hours and coordinate a coordinated disclosure and patch release.
