import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  bool _hideResultOverlay = false;
  final ImagePicker _picker = ImagePicker();
  
  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;

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
  void didUpdateWidget(covariant CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a new output arrives, show the result overlay again
    if (oldWidget.outputText != widget.outputText) {
      _hideResultOverlay = false;
      _showReasoning = false;
    }
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
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await pickedFile.readAsBytes();
      } else {
        final file = File(pickedFile.path);
        bytes = await file.readAsBytes();
      }
      
      // Set the picked image in the parent
      widget.onImageCaptured(bytes);
      // Then evaluate the image
      await widget.evaluateImage();
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 800;

      return Stack(
        fit: StackFit.expand,
              children: [
                // Hidden share canvas
                Offstage(
                  offstage: true,
                  child: RepaintBoundary(
                    key: _storyKey,
                    child: _StoryCanvas(
                      imageBytes: widget.pickedImageBytes,
                      text: widget.outputText ?? '',
                    ),
                  ),
                ),

          // Full-screen camera (or states)
          _buildFullScreenCamera(theme),

          // Result overlay: shows main answer and a button to reveal reasoning
          if (widget.outputText != null && !_hideResultOverlay)
            _buildResultOverlay(theme, isWide),

          // Top overlay: camera and upload buttons
          if (!kIsWeb)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.35),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                          tooltip: 'Take Photo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_showReasoning && _reasoningText != null) _buildReasoningPopup(theme, isWide),
        ],
      );
    });
  }

  Widget _buildFullScreenCamera(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? theme.colorScheme.surfaceVariant : Colors.black;
    
    // If we have a captured image, show it full screen
    if (widget.pickedImageBytes != null) {
    return Container(
        color: bg,
        child: Image.memory(
          widget.pickedImageBytes!,
          fit: BoxFit.contain,
      width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Web fallback
    if (kIsWeb) {
      return Container(
        color: bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('Camera preview not available on web', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
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
        ),
      );
    }

    // Permission/state handling
    if (!_isCameraPermissionGranted) {
      return Container(
        color: bg,
        child: const Center(
          child: Text('Camera permission required', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Initializing camera...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Full-screen, cover-scaling camera preview
    final previewSize = _cameraController!.value.previewSize;

    if (previewSize == null) {
      return Container(color: bg);
    }

    // The plugin reports landscape size; swap to match portrait if needed
    final double previewWidth = previewSize.height;
    final double previewHeight = previewSize.width;

    return Container(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildResultOverlay(ThemeData theme, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 72, // sits just above the capture button
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 520 : 520),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.22 : 0.14),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets, size: 20, color: theme.colorScheme.onSurface),
                const SizedBox(width: 10),
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _mainText,
                        style: TextStyle(
                          fontSize: isWide ? 16 : 15,
                          height: 1.3,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_reasoningText != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() { _showReasoning = true; });
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('Show reasoning'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _hideResultOverlay = true;
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
      ),
    );
  }


  Widget _buildReasoningPopup(ThemeData theme, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 84.0), // centered just above result box
        child: Material(
          elevation: 12,
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: isWide ? 420 : 320),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(isDark ? 0.98 : 0.98),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.26 : 0.16),
              ),
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
                    setState(() { _showReasoning = false; });
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
      ),
    );
  }


}

class _StoryCanvas extends StatelessWidget {
  final Uint8List? imageBytes;
  final String text;

  const _StoryCanvas({
    required this.imageBytes,
    required this.text,
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
