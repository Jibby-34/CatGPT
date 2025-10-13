import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

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
  final GlobalKey _storyKey = GlobalKey();

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final maxCardWidth = isWide ? 820.0 : 480.0;
        final imageHeight = isWide
            ? 360.0
            : (constraints.maxHeight.isFinite
                ? (constraints.maxHeight * 0.35).clamp(220.0, 340.0)
                : 300.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // Offstage story canvas used for capture
            Offstage(
              offstage: true,
              child: RepaintBoundary(
                key: _storyKey,
                child: _StoryCanvas(
                  imageBytes: widget.pickedImageBytes,
                  text: widget.outputText ?? '',
                  isAudio: false,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: maxCardWidth),
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
                          height: imageHeight,
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
                                  width: isWide ? 50 : 44,
                                  height: isWide ? 50 : 44,
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
                                          style: TextStyle(fontSize: isWide ? 18 : 16, height: 1.35),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                    IconButton(
                                      onPressed: widget.outputText == null ? null : _shareStory,
                                      icon: const Icon(Icons.ios_share),
                                      tooltip: 'Share',
                                    ),
                                  ],
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
                          constraints: BoxConstraints(maxWidth: isWide ? 420 : 300),
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
                                  style: TextStyle(fontSize: isWide ? 15 : 14, height: 1.35),
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
          ),
        );
      },
    );
  }

  Future<void> _shareStory() async {
    try {
      final boundary = _storyKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final xfile = XFile.fromData(pngBytes, name: 'catgpt_story.png', mimeType: 'image/png');
      await Share.shareXFiles([xfile], text: 'CatGPT');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }
}

class _StoryCanvas extends StatelessWidget {
  final Uint8List? imageBytes;
  final String text;
  final bool isAudio;

  const _StoryCanvas({
    required this.imageBytes,
    required this.text,
    required this.isAudio,
  });

  @override
  Widget build(BuildContext context) {
    // 1080x1920 Instagram story aspect
    return SizedBox(
      width: 1080,
      height: 1920,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageBytes != null)
              Opacity(
                opacity: 0.45,
                child: Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            Container(color: Colors.black.withOpacity(0.25)),
            Padding(
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.pets, color: Colors.white, size: 56),
                      SizedBox(width: 16),
                      Text(
                        'CatGPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 44,
                        height: 1.25,
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Icon(Icons.camera_alt_rounded, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Translated with CatGPT', style: TextStyle(color: Colors.white70, fontSize: 26)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
