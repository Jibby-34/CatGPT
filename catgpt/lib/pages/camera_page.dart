import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/share_service.dart';

class CameraPage extends StatefulWidget {
  final Uint8List? pickedImageBytes;
  final String? outputText;
  final Function(Uint8List) onImageCaptured;
  final Future<void> Function() onSelectImage;
  final VoidCallback onReset;
  final Future<void> Function(Uint8List) evaluateImage;

  const CameraPage({
    super.key,
    required this.pickedImageBytes,
    required this.outputText,
    required this.onImageCaptured,
    required this.onSelectImage,
    required this.onReset,
    required this.evaluateImage,
  });

  @override
  State<CameraPage> createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  int _currentCameraIndex = 0;
  
  // Zoom related variables
  double _baseZoomLevel = 1.0;
  double _currentZoomLevel = 1.0; // Track current zoom level ourselves
  double _currentScale = 1.0;

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

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (kIsWeb) return; // Camera preview not supported on web
    
    try {
      if (_cameras == null) {
        _cameras = await availableCameras();
      }
      if (_cameras!.isEmpty) return;

      final index = cameraIndex ?? _currentCameraIndex;
      if (index >= _cameras!.length) return;

      // Dispose previous controller if it exists
      await _cameraController?.dispose();

      _cameraController = CameraController(
        _cameras![index],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        // Initialize zoom level to default and reset camera zoom
        _baseZoomLevel = 1.0;
        _currentZoomLevel = 1.0;
        try {
          await _cameraController!.setZoomLevel(1.0);
        } catch (e) {
          // Ignore if zoom setting fails
        }
        setState(() {
          _currentCameraIndex = index;
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

  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final newIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _initializeCamera(cameraIndex: newIndex);
  }

  Future<void> takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      // Notify parent of captured image
      // The parent will handle showing ad prompt if needed and then evaluating the image
      widget.onImageCaptured(bytes);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  bool get isCameraReady => _isCameraInitialized && _cameraController != null;

  Future<void> _onScaleStart(ScaleStartDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    // Use the current zoom level we've been tracking
    _baseZoomLevel = _currentZoomLevel;
    _currentScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Calculate new zoom level based on scale
    _currentScale = details.scale;
    final newZoomLevel = _baseZoomLevel * _currentScale;

    // Use reasonable default zoom limits (most cameras support 1.0 to 8.0 or higher)
    const double minZoom = 1.0;
    const double maxZoom = 8.0;

    // Clamp zoom level to valid range
    final clampedZoom = newZoomLevel.clamp(minZoom, maxZoom);

    // Apply zoom to camera and update our tracked zoom level
    try {
      await _cameraController!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
    } catch (e) {
      debugPrint('Error setting zoom level: $e');
    }
  }

  Future<void> _onScaleEnd(ScaleEndDetails details) async {
    // Update base zoom level to current zoom level for next gesture
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // Use the zoom level we've been tracking
      _baseZoomLevel = _currentZoomLevel;
      _currentScale = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? theme.colorScheme.surfaceVariant : Colors.black;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final topOffset = (statusBarHeight + appBarHeight) * 0.30;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen camera preview (starts just below AppBar, extends to bottom behind navbar)
        Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildMainCameraContent(theme, isDark, bg),
        ),

        // Result overlay when there's output text
        if (widget.outputText != null) _buildResultOverlay(theme),
      ],
    );
  }

  Widget _buildMainCameraContent(ThemeData theme, bool isDark, Color bg) {
    // If we have a captured image, show it scaled to match the live preview
    if (widget.pickedImageBytes != null) {
      // If the camera controller is initialized we can mimic the preview's
      // cover-scaling by using the preview's reported dimensions.
      final previewSize = _cameraController?.value.previewSize;
      if (_cameraController != null && _cameraController!.value.isInitialized && previewSize != null) {
        // The plugin reports landscape sizes, swap to portrait dims.
        final double previewWidth = previewSize.height;
        final double previewHeight = previewSize.width;

        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: Container(
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: Image.memory(
                  widget.pickedImageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }

      // Fallback: contain the image if we can't determine preview size.
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: Container(
          color: bg,
          child: Image.memory(
            widget.pickedImageBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    // Web fallback
    if (kIsWeb) {
      return Container(
        color: bg,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Camera preview not available on web',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: widget.onSelectImage,
                    icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                    label: const Text(
                      'Upload Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Permission/state handling
    if (!_isCameraPermissionGranted) {
      return Container(
        color: bg,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera permission required',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: bg,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Initializing camera...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Full-screen, cover-scaling camera preview that fills available space
    final previewSize = _cameraController!.value.previewSize;

    if (previewSize == null) {
      return Container(color: bg);
    }

    // The plugin reports landscape size; swap to match portrait if needed
    final double cameraPreviewWidth = previewSize.height;
    final double cameraPreviewHeight = previewSize.width;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: GestureDetector(
        onDoubleTap: switchCamera,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Container(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cameraPreviewWidth,
              height: cameraPreviewHeight,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final mediaPadding = MediaQuery.of(context).padding;
    
    // Parse the output text to separate main text and reasoning
    final text = widget.outputText ?? '';
    final idx = text.indexOf('[');
    final mainText = idx == -1 ? text.trim() : text.substring(0, idx).trim();
    final reasoningText = idx != -1 && text.indexOf(']') > idx 
        ? text.substring(idx + 1, text.indexOf(']')).trim()
        : null;

    // Move translation box lower when an image has been captured
    final bottomPosition = widget.pickedImageBytes != null 
        ? 24.0 + mediaPadding.bottom  // Lower position after photo is taken
        : 96.0 + mediaPadding.bottom + 24; // Original position above navbar

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPosition,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.98)
                  : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        mainText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: widget.onReset,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                if ((reasoningText != null) || (widget.pickedImageBytes != null && widget.outputText != null)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (reasoningText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  reasoningText!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (reasoningText != null && widget.pickedImageBytes != null && widget.outputText != null)
                        const SizedBox(width: 8),
                      if (widget.pickedImageBytes != null && widget.outputText != null)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.tertiary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                try {
                                  await ShareService.shareInstagramStyle(
                                    imageBytes: widget.pickedImageBytes!,
                                    text: widget.outputText!,
                                    context: context,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error sharing: ${e.toString()}')),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Share',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

