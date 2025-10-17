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
    return LayoutBuilder(builder: (context, constraints) {
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
                // Hidden share canvas
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
                _buildMainCard(theme, maxCardWidth, imageHeight, isWide),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMainCard(
      ThemeData theme, double maxCardWidth, double imageHeight, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: maxCardWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDark 
              ? [theme.colorScheme.surface.withOpacity(0.9), theme.colorScheme.surfaceVariant.withOpacity(0.5)]
              : [Colors.white.withOpacity(0.9), const Color(0xFFEFF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
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
                  color: isDark ? theme.colorScheme.surfaceVariant : Colors.grey[200],
                  child: widget.pickedImageBytes != null
                      ? Image.memory(widget.pickedImageBytes!, fit: BoxFit.cover)
                      : Center(
                          child: Icon(
                            Icons.pets, 
                            size: 92, 
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap the camera button to take a photo',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
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
              if (widget.outputText != null)
                _buildOutputCard(theme, isWide),
            ],
          ),
          if (_showReasoning && _reasoningText != null)
            _buildReasoningPopup(theme, isWide),
        ],
      ),
    );
  }

  Widget _buildOutputCard(ThemeData theme, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isWide ? 50 : 44,
            height: isWide ? 50 : 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.pets, 
              size: 26,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mainText,
                  style: TextStyle(
                    fontSize: isWide ? 18 : 16, 
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
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
                      label: Text(_showReasoning
                          ? 'Hide Reasoning'
                          : 'Show Reasoning'),
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
                    const SnackBar(content: Text('Copied to clipboard (mock)')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copy',
              ),
              IconButton(
                onPressed: _shareStory,
                icon: const Icon(Icons.ios_share),
                tooltip: 'Share',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningPopup(ThemeData theme, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    return Positioned(
      right: 12,
      bottom: 12,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: isWide ? 420 : 300),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 8),
              )
            ],
            border: Border.all(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.12)),
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
                  style: TextStyle(
                    fontSize: isWide ? 15 : 14, 
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _showReasoning = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close, 
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareStory() async {
    try {
      // 🔹 Wait for all frames to finish painting before capture
      await Future.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;

      // 🔹 Find the boundary for the story widget
      final renderObject = _storyKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story not ready to share — please try again.')),
        );
        return;
      }

      // 🔹 Double-check that it’s painted (avoid debugNeedsPaint issue)
      if (renderObject.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 100));
        await WidgetsBinding.instance.endOfFrame;
      }

      // 🔹 Capture the widget as image
      final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert to image bytes');
      }

      // 🔹 Convert to PNG and share
      final pngBytes = byteData.buffer.asUint8List();
      final file = XFile.fromData(
        pngBytes,
        name: 'catgpt_result.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles([file], text: 'Check out my CatGPT translation 🐾');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
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
                      Text('Translated with CatGPT',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 26)),
                    ],
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
