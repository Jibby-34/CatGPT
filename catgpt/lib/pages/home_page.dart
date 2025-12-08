import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:CatGPT/widgets/catgpt_logo.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:camera/camera.dart';

import 'history_page.dart';
import 'settings_page.dart';
import '../services/share_service.dart';

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
    // Use test ad unit ID during development, replace with your real ad unit ID for production
    String adUnitId;
    if (kDebugMode) {
      adUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Google test banner ad unit ID
    } else {
      // Check platform and use appropriate ad unit ID
      if (Platform.isAndroid) {
        adUnitId = const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/8973110065');
      } else if (Platform.isIOS) {
        adUnitId = const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/9965802154');
      } else {
        // Fallback for other platforms
        adUnitId = const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/8973110065');
      }
    }
    
    // kDebugMode is automatically true when running 'flutter run' (debug builds)
    // kDebugMode is automatically false when running 'flutter run --release' (release builds)
    debugPrint('Loading banner ad in ${kDebugMode ? "DEBUG" : "RELEASE"} mode on ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown"} with ID: $adUnitId');
    
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded successfully');
          if (mounted) {
            setState(() {
              _isBannerLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: ${error.code} - ${error.message}');
          debugPrint('Domain: ${error.domain}, ResponseInfo: ${error.responseInfo}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isBannerLoaded = false;
            });
          }
        },
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) => debugPrint('Banner ad closed'),
      ),
      request: const AdRequest(),
    );
    ad.load();
    _bannerAd = ad;
  }

  void _loadRewardedAd() {
    // Use test ad unit ID during development, replace with your real ad unit ID for production
    // kDebugMode is automatically true when running 'flutter run' or in debug builds
    // kDebugMode is automatically false when running 'flutter run --release' or in release builds
    String adUnitId;
    if (kDebugMode) {
      adUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded ad unit ID
    } else {
      // Check platform and use appropriate ad unit ID
      if (Platform.isAndroid) {
        adUnitId = const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3872170088');
      } else if (Platform.isIOS) {
        adUnitId = const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3820030354');
      } else {
        // Fallback for other platforms
        adUnitId = const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3872170088');
      }
    }
    
    debugPrint('Loading rewarded ad in ${kDebugMode ? "DEBUG" : "RELEASE"} mode on ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown"} with ID: $adUnitId');
    
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded ad loaded successfully');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: ${error.code} - ${error.message}');
          debugPrint('Domain: ${error.domain}, ResponseInfo: ${error.responseInfo}');
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

  void _clearHistory() {
    setState(() {
      translationHistory.clear();
      imageHistory.clear();
    });
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

  Future<Uint8List?> pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
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
      debugPrint('pickImageFromGallery error: $e');
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
      final url = Uri.parse('https://my-proxy-server.image-proxy-gateway.workers.dev/');
      final headers = {'Content-Type': 'application/json'};
      final base64Image = base64Encode(_pickedImageBytes!);

      final body = jsonEncode({
        "imageBase64": base64Image,
        "prompt": "Using the given image, translate the cat's body langauge and enviornment in a dialogue-like, funny/meme phrase (no one-word replies). If there is a signifcant object in the image (ex: shoes, food bowl, car) include the object in the humor of your translation. Basic things like the ground or other things such as that do not count as significant objects, do not include these in your translation, If there is not a signifcant object, simply translate what the body language is saying. DO NOT USE ANY HUMAN NAMES IN THE TRANSLATION. DO NOT INCLUDE OBJECT THAT ARE NOT IN THE IMAGE IN THE TRANSLATION. If the cat in the image is a human with cat features, mention this detail in the translation. If the cat is a human female with cat features and the image is sexually suggestive (ex: skin showing or exaggerated porportions), then make sure to include this detail and mild sexual suggestiveness in your response (using keywords like catgirl). If the cat is irregular in any way (such as a meme cat with a human face), mention this in the translation Use few emojis in the translation. All text must stay on one line. If not a cat, say 'No cat detected!' only. Add reasoning in one [] with exactly 2 adjectives. DO NOT INCLUDE REASONING IF THERE IS NO CAT IN THE IMAGE. TREAT EACH TRANSLATION AS ITS OWN. DO NOT REFRENCE OTHER TRANSLATIONS OR USE ANY CONTEXT GATHERED OTHER THAN THE CURRENT IMAGE. ONLY INCLUDE THE TRANSLATION AND REASONING, NO OTHER WORDS ALLOWED!!! DO NOT MAKE ANY JOKES ABOUT GAMES ON A PHONE"
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;
        if (text == null) {
          debugPrint('Invalid server response. Body: \n${response.body}');
          throw Exception('Invalid server response');
        }
        setState(() => _outputText = text);

        if (!text.contains('No cat detected!')) {
          _addHistoryEntry(text: text, imageBytes: _pickedImageBytes);
          await _showRewardedAdIfAvailable();
        }
      } else {
        debugPrint('Server error response (${response.statusCode}): \n${response.body}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server Error: ${response.statusCode}')));
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
          children: [
            CatGptLogo(size: 35, isDark: widget.isDarkMode),
            const SizedBox(width: 8),
            const Text('CatGPT'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    isDarkMode: widget.isDarkMode,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
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
          ? SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton(
                onPressed: _onTakePhoto,
                tooltip: 'Take Photo',
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.camera_alt_rounded, size: 40),
              ),
            )
                  : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                final bytes = await pickImageFromGallery();
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
                  onClearHistory: _clearHistory,
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
        
        // Top overlay: image button
        if (!kIsWeb)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.35),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      final bytes = await pickImageFromGallery();
                      if (bytes != null) {
                        await evaluateImage();
                      }
                    },
                    icon: const Icon(Icons.image_rounded, color: Colors.white, size: 24),
                    tooltip: 'Select Image',
                  ),
                ),
              ),
            ),
          ),
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
                  final bytes = await pickImageFromGallery();
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
      bottom: 110, // sits just above the capture button
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
                // Share button
                if (_pickedImageBytes != null && _outputText != null)
                  InkWell(
                    onTap: () async {
                      try {
                        await ShareService.shareInstagramStyle(
                          imageBytes: _pickedImageBytes!,
                          text: _outputText!,
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
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.share_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
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
    // Replaced 3 action cards with 2 primary buttons (Upload, Camera)


    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final horizontalPadding = isWide ? 28.0 : 18.0;
        final topPadding = isWide ? 24.0 : 16.0;

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
                        'Translate your cat\'s vibes from a photo!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Two primary buttons replacing the previous three boxes
                if (isWide)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: onUploadAndTranslate,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Upload Image'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: onOpenCamera,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Open Camera'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: onUploadAndTranslate,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Upload Image'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: onOpenCamera,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Open Camera'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
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
                          const SizedBox(width: 8),
                          if (img != null)
                            InkWell(
                              onTap: () async {
                                try {
                                  await ShareService.shareInstagramStyle(
                                    imageBytes: img,
                                    text: text,
                                    context: context,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error sharing: ${e.toString()}')),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.share_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
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
