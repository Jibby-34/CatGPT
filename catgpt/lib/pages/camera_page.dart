import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  final Uint8List? pickedImageBytes;
  final String? outputText;
  final Future<Uint8List?> Function() pickImage;
  final Future<void> Function() evaluateImage;

  const CameraPage({
    super.key,
    required this.pickedImageBytes,
    required this.outputText,
    required this.pickImage,
    required this.evaluateImage,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _showReasoning = false;

  String get _mainText {
    final text = widget.outputText ?? '';
    final idx = text.indexOf('[');
    if (idx == -1) return text.trim();
    return text.substring(0, idx).trim();
  }

  String? get _reasoningText {
    final text = widget.outputText ?? '';
    final start = text.indexOf('[');
    final end = text.indexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start + 1, end).trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.9), const Color(0xFFEFF3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 300,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: widget.pickedImageBytes != null
                              ? Image.memory(widget.pickedImageBytes!, fit: BoxFit.cover)
                              : const Center(
                                  child: Icon(Icons.pets, size: 92, color: Colors.black26),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tap the camera button to take a photo'),
                          if (kIsWeb)
                            TextButton.icon(
                              onPressed: () async {
                                final bytes = await widget.pickImage();
                                if (bytes == null) return;
                                await widget.evaluateImage();
                              },
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Upload'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: widget.outputText != null
                            ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 6),
                                    )
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                margin: const EdgeInsets.only(top: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.pets, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _mainText,
                                            style: const TextStyle(fontSize: 16, height: 1.35),
                                          ),
                                          const SizedBox(height: 8),
                                          if (_reasoningText != null)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _showReasoning = !_showReasoning;
                                                  });
                                                },
                                                icon: Icon(
                                                  _showReasoning
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                ),
                                                label: Text(
                                                  _showReasoning ? 'Hide Reasoning' : 'Show Reasoning',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text('Copied to clipboard (mock)')),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_outlined),
                                      tooltip: 'Copy',
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  if (_showReasoning && _reasoningText != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 8),
                              )
                            ],
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _reasoningText!,
                                  style: const TextStyle(fontSize: 14, height: 1.35),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showReasoning = false;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
