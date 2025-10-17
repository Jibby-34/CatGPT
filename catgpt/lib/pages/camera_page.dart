import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraPage extends StatefulWidget {
  final Uint8List? pickedImageBytes;
  final String? outputText;
  final Future<Uint8List?> Function() pickImage;
  final Future<void> Function() evaluateImage;
  final Function(Uint8List) onImageCaptured;

  const CameraPage({
    super.key,
    required this.pickedImageBytes,
    required this.outputText,
    required this.pickImage,
    required this.evaluateImage,
    required this.onImageCaptured,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  bool _showReasoning = false;
  final GlobalKey _storyKey = GlobalKey();
  
  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  final ImagePicker _picker = ImagePicker();

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) return; // Camera preview not supported on web
    
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) return;

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraPermissionGranted = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      // Set the captured image in the parent
      widget.onImageCaptured(bytes);
      // Then evaluate the image
      await widget.evaluateImage();
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        // Set the picked image in the parent
        widget.onImageCaptured(bytes);
        // Then evaluate the image
        await widget.evaluateImage();
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 800;
      final maxCardWidth = isWide ? 820.0 : 480.0;

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
                _buildCameraPreview(theme, maxCardWidth, isWide),
                if (widget.outputText != null) ...[
                  const SizedBox(height: 16),
                  _buildOutputCard(theme, isWide),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCameraPreview(ThemeData theme, double maxCardWidth, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    final imageHeight = isWide ? 400.0 : 300.0;
    
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
                  child: _buildCameraContent(theme),
                ),
              ),
              const SizedBox(height: 16),
              _buildCameraControls(theme),
            ],
          ),
          if (_showReasoning && _reasoningText != null)
            _buildReasoningPopup(theme, isWide),
        ],
      ),
    );
  }

  Widget _buildCameraContent(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    // If we have a captured image, show it
    if (widget.pickedImageBytes != null) {
      return Image.memory(widget.pickedImageBytes!, fit: BoxFit.cover);
    }
    
    // If on web, show upload option
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera preview not available on web',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final bytes = await widget.pickImage();
                if (bytes == null) return;
                await widget.evaluateImage();
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Image'),
            ),
          ],
        ),
      );
    }
    
    // Show camera preview or loading/error state
    if (!_isCameraPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera permission required',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show camera preview
    return CameraPreview(_cameraController!);
  }

  Widget _buildCameraControls(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Image upload button (transparent)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.3),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: IconButton(
            onPressed: _pickImageFromGallery,
            icon: Icon(
              Icons.image_outlined,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Upload from Gallery',
          ),
        ),
        
        // Camera capture button
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: kIsWeb ? null : _takePicture,
            icon: Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Take Photo',
          ),
        ),
        
        // Placeholder for symmetry
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: IconButton(
            onPressed: null,
            icon: Icon(
              Icons.camera_alt_rounded,
              color: Colors.transparent,
              size: 28,
            ),
          ),
        ),
      ],
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
