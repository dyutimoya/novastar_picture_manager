import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/system_integration_service.dart';

class DefaultViewerDialog extends StatefulWidget {
  const DefaultViewerDialog({super.key});

  @override
  State<DefaultViewerDialog> createState() => _DefaultViewerDialogState();
}

class _DefaultViewerDialogState extends State<DefaultViewerDialog> {
  bool _isChecking = false;
  bool _isLinuxDefault = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!kIsWeb && Platform.isLinux) {
      setState(() => _isChecking = true);
      final isDef = await SystemIntegrationService.isLinuxDefaultViewer();
      if (mounted) {
        setState(() {
          _isLinuxDefault = isDef;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _applyLinuxDefault() async {
    setState(() => _isChecking = true);
    final ok = await SystemIntegrationService.setLinuxAsDefaultViewer();
    if (mounted) {
      setState(() {
        _isChecking = false;
        _isLinuxDefault = ok;
        _isSuccess = ok;
        _statusMessage = ok
            ? 'Successfully registered Novastar Picture Manager as default image viewer!'
            : 'Could not register automatically. You can run the terminal command below.';
      });
    }
  }

  Future<void> _exportWindowsReg() async {
    final folder = await FilePicker.getDirectoryPath();
    if (folder != null) {
      final path = await SystemIntegrationService.exportWindowsRegFile(folder);
      if (mounted && path != null) {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Exported registry script to $path. Double-click the .reg file to install associations!';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.settings_applications, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Default Image Viewer & Associations',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Configure your operating system to open images directly in Novastar Picture Manager when double-clicked in File Manager or Windows Explorer.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              // Supported Formats Pills
              const Text(
                'Supported File Types:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: SystemIntegrationService.supportedExtensions.map((ext) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B38),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '.$ext',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Status message banner
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isSuccess ? Colors.greenAccent : Colors.orangeAccent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.warning_amber,
                        color: _isSuccess ? Colors.greenAccent : Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(color: _isSuccess ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Platform Section
              if (!kIsWeb && Platform.isLinux) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262632),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.laptop_chromebook, color: Colors.blueAccent),
                          const SizedBox(width: 10),
                          const Text(
                            'Linux Desktop Integration',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          if (_isLinuxDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Currently Default',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Registers a .desktop launcher entry in ~/.local/share/applications and sets xdg-mime associations for all image formats.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Set as Default Image Viewer'),
                            onPressed: _isChecking ? null : _applyLinuxDefault,
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Open System Settings'),
                            onPressed: SystemIntegrationService.openSystemDefaultAppsSettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Or execute via terminal:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'xdg-mime default picture-manager-pro.desktop image/jpeg image/png image/webp',
                                style: TextStyle(color: Colors.lightGreenAccent, fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: Colors.white54),
                              tooltip: 'Copy Command',
                              onPressed: () {
                                Clipboard.setData(
                                  const ClipboardData(
                                    text: 'xdg-mime default picture-manager-pro.desktop image/jpeg image/png image/webp image/bmp image/tiff',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Command copied to clipboard!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Windows Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF262632),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.window, color: Colors.blueAccent),
                        SizedBox(width: 10),
                        Text(
                          'Windows Desktop Integration',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Windows 10 & 11 require registering file type handlers or selecting your default photo viewer in Windows Settings.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C2C3C),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Export Windows .reg Association Script'),
                          onPressed: _exportWindowsReg,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Windows Default Apps Settings'),
                          onPressed: SystemIntegrationService.openSystemDefaultAppsSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
