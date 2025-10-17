import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

class AudioPage extends StatefulWidget {
  final Uint8List? recordedAudioBytes;
  final String? outputText;
  final Future<Uint8List?> Function(String path) recordAudio;
  final Future<void> Function() evaluateAudio;

  const AudioPage({
    super.key,
    required this.recordedAudioBytes,
    required this.outputText,
    required this.recordAudio,
    required this.evaluateAudio,
  });

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final GlobalKey _storyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }


  Future<void> _startRecording() async {
    try {
      if (kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording is not supported on web')),
        );
        return;
      }
      if (await _audioRecorder.hasPermission()) {
        // Get the temporary directory for audio recording
        final Directory tempDir = await getTemporaryDirectory();
        final String audioPath = '${tempDir.path}/audio_recording.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: audioPath);
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _pulseController.repeat(reverse: true);
        _startTimer();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        await widget.recordAudio(path);
        await widget.evaluateAudio();
      }
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
      _pulseController.stop();
      _pulseController.reset();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        setState(() {
          _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
        });
        if (_recordingDuration.inSeconds < 10) {
          _startTimer();
        } else {
          _stopRecording();
        }
      }
    });
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final maxCardWidth = isWide ? 820.0 : 480.0;
        final vizHeight = isWide
            ? 260.0
            : (constraints.maxHeight.isFinite
                ? (constraints.maxHeight * 0.32).clamp(180.0, 240.0)
                : 200.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Offstage(
              offstage: true,
              child: RepaintBoundary(
                key: _storyKey,
                child: _StoryCanvas(
                  imageBytes: null,
                  text: widget.outputText ?? '',
                  isAudio: true,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: theme.brightness == Brightness.dark
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
              child: Column(
                children: [
                  // Audio visualization area
                  Container(
                    height: vizHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isRecording 
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : (theme.brightness == Brightness.dark ? theme.colorScheme.surfaceVariant : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(12),
                      border: _isRecording 
                          ? Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            )
                          : null,
                    ),
                    child: _isRecording
                        ? AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        size: 64,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Recording...',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(_recordingDuration),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mic_none,
                                  size: 64,
                                  color: theme.brightness == Brightness.dark ? Colors.white38 : Colors.black26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to record your cat\'s meow',
                                  style: TextStyle(
                                    fontSize: isWide ? 17 : 16,
                                    color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Up to 10 seconds',
                                  style: TextStyle(
                                    fontSize: isWide ? 15 : 14,
                                    color: theme.brightness == Brightness.dark ? Colors.white60 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isRecording 
                            ? 'Recording in progress...'
                            : 'Hold the record button to start',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (widget.recordedAudioBytes != null)
                        TextButton.icon(
                          onPressed: () async {
                            await _startRecording();
                          },
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Re-record'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isRecording && widget.recordedAudioBytes == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.mic),
                        label: const Text('Start Recording'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_isRecording)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: widget.outputText != null
                        ? Container(
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
                                    color: theme.colorScheme.primary.withOpacity(
                                      theme.brightness == Brightness.dark ? 0.2 : 0.12
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.pets, 
                                    size: 26,
                                    color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.outputText!,
                                    style: TextStyle(
                                      fontSize: isWide ? 18 : 16, 
                                      height: 1.35,
                                      color: theme.colorScheme.onSurface,
                                    ),
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
    return SizedBox(
      width: 1080,
      height: 1920,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageBytes != null)
              Opacity(
                opacity: 0.3,
                child: Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            Container(color: Colors.black.withOpacity(0.25)),
            Padding(
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isAudio ? Icons.graphic_eq : Icons.pets, color: Colors.white, size: 56),
                      const SizedBox(width: 16),
                      const Text(
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
                      Icon(Icons.mic_none, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Translated from meow with CatGPT', style: TextStyle(color: Colors.white70, fontSize: 26)),
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
