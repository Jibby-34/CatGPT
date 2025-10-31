import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:catspeak/widgets/catgpt_logo.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:camera/camera.dart';

import 'history_page.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  
  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Uint8List? _pickedImageBytes;
  int _currentIndex = 1;
  String? _outputText;
  bool _isLoading = false;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  RewardedAd? _rewardedAd;

  List<String> translationHistory = [];
  List<Uint8List?> imageHistory = [];

  final ImagePicker _picker = ImagePicker();
  SharedPreferences? _prefs;
  
  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefsAndHistory();
    _loadBannerAd();
    _loadRewardedAd();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
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

  Future<void> _loadPrefsAndHistory() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final texts = _prefs!.getStringList('translationHistory') ?? [];
      final imagesB64 = _prefs!.getStringList('imageHistory') ?? [];
      
      if (mounted) {
        setState(() {
          translationHistory = texts;
          imageHistory = imagesB64.map((s) {
            if (s.isEmpty) return null;
            try {
              return base64Decode(s);
            } catch (e) {
              debugPrint('Error decoding image: $e');
              return null;
            }
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveHistory() async {
    if (_prefs == null) return;
    // Normalize list lengths
    final maxLen = translationHistory.length;
    void padTo<T>(List<T?> list) { while (list.length < maxLen) list.add(null); }
    padTo(imageHistory);

    await _prefs!.setStringList('translationHistory', translationHistory);
    await _prefs!.setStringList('imageHistory', imageHistory.map((b) => b == null ? '' : base64Encode(b)).toList());
  }
  void _loadBannerAd() {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-6076315103458124/2564470304'),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {
          _isBannerLoaded = true;
        }),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    ad.load();
    _bannerAd = ad;
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-6076315103458124/7232868279'),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> _showRewardedAdIfAvailable() async {
    final ad = _rewardedAd;
    if (ad == null) return;
    await ad.show(onUserEarnedReward: (ad, reward) {});
    ad.dispose();
    _rewardedAd = null;
    _loadRewardedAd();
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

  void _resetCameraState() {
    setState(() {
      _pickedImageBytes = null;
      _outputText = null;
    });
  }


  void _addHistoryEntry({required String text, Uint8List? imageBytes}) {
    translationHistory.add(text);
    imageHistory.add(imageBytes);
    _saveHistory();
  }

  Future<Uint8List?> pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await pickedFile.readAsBytes();
      } else {
        final file = File(pickedFile.path);
        bytes = await file.readAsBytes();
      }
      if (mounted) {
        setState(() {
          _pickedImageBytes = bytes;
          // Clear any previous text so other tabs don't show stale content
          _outputText = null;
        });
      }
      return bytes;
    } catch (e) {
      debugPrint('pickImage error: $e');
      return null;
    }
  }

  Future<void> _onTakePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // Fallback to image picker if camera is not available
      final bytes = await pickImage();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No image selected.')));
        return;
      }
      setState(() {
        _pickedImageBytes = bytes;
        _outputText = null;
      });
      await evaluateImage();
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      setState(() {
        _pickedImageBytes = bytes;
        _outputText = null;
      });
      await evaluateImage();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error taking photo.')));
    }
  }


  Future<void> evaluateImage() async {
    if (_pickedImageBytes == null) return;
    setState(() => _isLoading = true);

    try {
      const apiKey = 'AIzaSyCy51BM9vdmk6ovRnvj3pB7lavyaMCu2qQ';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent?key=$apiKey');

      final headers = {'Content-Type': 'application/json'};
      final base64Image = base64Encode(_pickedImageBytes!);

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Describe the cat's body language in a short, dialogue-like, funny/meme phrase (no one-word replies). Use few emojis. If not a cat, say 'No cat detected!' only. Add reasoning in one [] with exactly 3 short phrases. Example: If I fits, I sits. [sitting down, undersized box, fat]"
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] as String?;
        if (text == null) throw Exception('Unexpected response shape.');

        setState(() {
            _outputText = text;
          });
        if (!text.contains('No cat detected!')) {
          setState(() {
            _addHistoryEntry(text: text, imageBytes: _pickedImageBytes);
          });
          await _showRewardedAdIfAvailable();
        }
      } else {
        debugPrint('API error ${response.statusCode}: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('API Error: ${response.statusCode}')));
      }
    } catch (e) {
      debugPrint('evaluateImage error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error analyzing image.')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CatGptLogo(size: 35),
            SizedBox(width: 8),
            Text('CatGPT'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              widget.onThemeChanged(!widget.isDarkMode);
            },
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content area
          SafeArea(child: Column(
            children: [
              // Add top padding to account for banner ad
              if (_isBannerLoaded && _bannerAd != null)
                SizedBox(height: _bannerAd!.size.height.toDouble()),
              // Main content with adjusted spacing
              Expanded(child: _buildBody()),
            ],
          )),
          // Banner ad positioned at the top with higher z-index
          if (_isBannerLoaded && _bannerAd != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ),
            ),
          // Loading overlay on top
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _onTakePhoto,
              tooltip: 'Take Photo',
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.camera_alt_rounded, size: 28),
            )
                  : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: theme.colorScheme.surface,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home_filled,
                  size: 28,
                  color: _currentIndex == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () => setState(() {
                  // Reset camera state when leaving camera tab
                  if (_currentIndex == 1) _resetCameraState();
                  _currentIndex = 0;
                  _outputText = null;
                }),
                tooltip: 'Home',
              ),
              IconButton(
                icon: Icon(
                  Icons.camera_alt_rounded,
                  size: 28,
                  color: _currentIndex == 1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () => setState(() {
                  _currentIndex = 1;
                  // Clear cross-tab artifacts
                  _outputText = null;
                }),
                tooltip: 'Camera',
              ),
              IconButton(
                icon: Icon(
                  Icons.history_rounded,
                  size: 28,
                  color: _currentIndex == 2
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () => setState(() {
                  // Reset camera state when leaving camera tab
                  if (_currentIndex == 1) _resetCameraState();
                  _currentIndex = 2;
                  // Avoid showing stale text in other tabs after returning
                  _outputText = null;
                }),
                tooltip: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _currentIndex == 0
          ? _HomePageContent(
              onOpenCamera: () => setState(() {
                _currentIndex = 1;
                _outputText = null;
              }),
              onOpenHistory: () => setState(() {
                _currentIndex = 2;
                _outputText = null;
              }),
              onUploadAndTranslate: () async {
                final bytes = await pickImage();
                if (bytes == null) return;
                await evaluateImage();
              },
              onTakePhotoAndTranslate: _onTakePhoto,
              recentTranslations: translationHistory,
              recentImages: imageHistory,
            )
          : _currentIndex == 1
              ? _buildCameraPreview()
              : HistoryPage(
                  translationHistory: translationHistory,
                  imageHistory: imageHistory,
                ),
    );
  }

  Widget _buildCameraPreview() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? theme.colorScheme.surfaceVariant : Colors.black;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main camera preview or captured image
        _buildMainCameraContent(theme, isDark, bg),
        
        // Result overlay when there's output text
        if (_outputText != null) _buildResultOverlay(theme),
      ],
    );
  }

  Widget _buildMainCameraContent(ThemeData theme, bool isDark, Color bg) {
    // If we have a captured image, show it full screen
    if (_pickedImageBytes != null) {
      return Container(
        color: bg,
        child: Image.memory(
          _pickedImageBytes!,
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
                  final bytes = await pickImage();
                  if (bytes == null) return;
                  await evaluateImage();
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

  Widget _buildResultOverlay(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    // Parse the output text to separate main text and reasoning
    final text = _outputText ?? '';
    final idx = text.indexOf('[');
    final mainText = idx == -1 ? text.trim() : text.substring(0, idx).trim();
    final reasoningText = idx != -1 && text.indexOf(']') > idx 
        ? text.substring(idx + 1, text.indexOf(']')).trim()
        : null;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 72, // sits just above the capture button
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                        mainText,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reasoningText != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              // Show reasoning in a snackbar or dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reasoning: $reasoningText'),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
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
                    _resetCameraState();
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.28),
      child: const Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Padding(
              padding: EdgeInsets.all(18.0),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageContent extends StatelessWidget {
  final VoidCallback onOpenCamera;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onUploadAndTranslate;
  final Future<void> Function() onTakePhotoAndTranslate;
  final List<String> recentTranslations;
  final List<Uint8List?> recentImages;

  const _HomePageContent({
    required this.onOpenCamera,
    required this.onOpenHistory,
    required this.onUploadAndTranslate,
    required this.onTakePhotoAndTranslate,
    required this.recentTranslations,
    required this.recentImages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _ActionCard(
        color: theme.colorScheme.primary,
        icon: Icons.camera_alt_rounded,
        title: 'Take Photo',
        subtitle: 'Snap your cat and translate vibes',
        onTap: () { onTakePhotoAndTranslate(); },
      ),
      _ActionCard(
        color: Colors.teal,
        icon: Icons.upload_file_outlined,
        title: 'Upload Image',
        subtitle: 'Pick a photo from your device',
        onTap: () { onUploadAndTranslate(); },
      ),
      _ActionCard(
        color: Colors.orange,
        icon: Icons.history_rounded,
        title: 'History',
        subtitle: 'Review recent translations',
        onTap: onOpenHistory,
      ),
    ];


    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final horizontalPadding = isWide ? 28.0 : 18.0;
        final topPadding = isWide ? 24.0 : 16.0;

        // Grid size: 1 row on wide (4 columns), 2 rows on narrow (2 columns)
        final crossAxisCount = isWide ? 4 : 2;
        final rows = (actions.length / crossAxisCount).ceil();
        final gridHeight = isWide ? 150.0 : (rows == 2 ? 280.0 : 150.0);

        // Recent items: cap to 2 to avoid scroll
        final maxRecent = 2;
        final hasRecent = recentTranslations.isNotEmpty;
        final recentItems = hasRecent
            ? List.generate(recentTranslations.length, (i) => i)
                .reversed
                .take(maxRecent)
                .toList()
            : const <int>[];

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Centered logo banner
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CatGptLogo(size: isWide ? 72 : 60),
                      const SizedBox(height: 8),
                      Text(
                        'CatGPT',
                        textAlign: TextAlign.center,
                        style: (isWide ? theme.textTheme.headlineLarge : theme.textTheme.headlineMedium)
                            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Translate your cat\'s vibes from photos or meows — fast.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.8 : 1.2,
                    ),
                    itemCount: actions.length,
                    itemBuilder: (context, index) => actions[index],
                  ),
                ),
                const SizedBox(height: 24),
                if (hasRecent) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        onPressed: onOpenHistory,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...recentItems.map((idx) {
                    final text = recentTranslations[idx];
                    final img = idx < recentImages.length ? recentImages[idx] : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              image: img != null
                                  ? DecorationImage(image: MemoryImage(img), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: img != null 
                                ? null 
                                : Icon(
                                    Icons.pets, 
                                    size: 24,
                                    color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                height: 1.25,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (!hasRecent) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No recent translations yet. Try a photo or meow!',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

}

class _ActionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(isDark ? 0.2 : 0.12), 
              color.withOpacity(isDark ? 0.08 : 0.04)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.25 : 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54, 
                      fontSize: 11
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
