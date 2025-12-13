import 'dart:async';
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
// import 'package:in_app_purchase/in_app_purchase.dart';
import '../constants/purchase_constants.dart';

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
  RewardedAd? _rewardedAd;
  bool _adsRemoved = false;

  List<String> translationHistory = [];
  List<Uint8List?> imageHistory = [];
  Set<int> favorites = {}; // Track favorited entry indices
  int _consecutiveNoCatCount = 0; // Track consecutive "no cat detected" responses

  final ImagePicker _picker = ImagePicker();
  SharedPreferences? _prefs;
  
  // In-app purchase
  // final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  // StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  
  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
    //   _onPurchaseUpdated,
    //   onError: (error) => debugPrint('Purchase stream error: $error'),
    // );
    _initializeState();
  }

  Future<void> _initializeState() async {
    await _loadPrefsAndHistory();
    // Verify purchase status with store before trusting SharedPreferences
    // await _verifyPurchaseStatus();
    if (!_adsRemoved) {
      _loadRewardedAd();
    }
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // _purchaseSubscription?.cancel();
    _cameraController?.dispose();
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
      final favoritesList = _prefs!.getStringList('favorites') ?? [];
      // Start with false - will verify with store
      _adsRemoved = false;
      _consecutiveNoCatCount = _prefs!.getInt('consecutiveNoCatCount') ?? 0;
      
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
          favorites = favoritesList.map((s) => int.tryParse(s) ?? -1).where((i) => i >= 0).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveNoCatCount() async {
    if (_prefs == null) return;
    await _prefs!.setInt('consecutiveNoCatCount', _consecutiveNoCatCount);
  }

  // Future<void> _verifyPurchaseStatus() async {
  //   try {
  //     final available = await _inAppPurchase.isAvailable();
  //     if (!available) {
  //       debugPrint('Store not available for purchase verification');
  //       // If store unavailable, clear any stale purchase data
  //       final hadStaleData = _prefs?.getBool(noAdsPrefsKey) == true;
  //       if (hadStaleData) {
  //         await _prefs?.setBool(noAdsPrefsKey, false);
  //         debugPrint('Cleared stale purchase data (store unavailable)');
  //       }
  //       return;
  //     }

  //     // Check if SharedPreferences claims a purchase exists
  //     final prefsClaimsPurchase = _prefs?.getBool(noAdsPrefsKey) == true;
      
  //     // Restore purchases to verify actual purchase status
  //     // This will fire events through the purchase stream
  //     await _inAppPurchase.restorePurchases();
      
  //     // Wait for restore to process
  //     await Future.delayed(const Duration(milliseconds: 1000));
      
  //     // If SharedPreferences claimed a purchase but store doesn't confirm, clear it
  //     if (prefsClaimsPurchase && !_adsRemoved) {
  //       debugPrint('SharedPreferences claimed purchase but store does not confirm - clearing');
  //       await _prefs?.setBool(noAdsPrefsKey, false);
  //     }
  //   } catch (e) {
  //     debugPrint('Error verifying purchase status: $e');
  //     // On error, clear any stale purchase data
  //     if (_prefs?.getBool(noAdsPrefsKey) == true) {
  //       await _prefs?.setBool(noAdsPrefsKey, false);
  //       debugPrint('Cleared stale purchase data (verification error)');
  //     }
  //   }
  // }

  // void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
  //   bool foundNoAdsPurchase = false;
    
  //   for (final purchase in purchases) {
  //     if (purchase.productID != noAdsProductId) continue;

  //     switch (purchase.status) {
  //       case PurchaseStatus.purchased:
  //       case PurchaseStatus.restored:
  //         foundNoAdsPurchase = true;
  //         debugPrint('No Ads purchase verified: ${purchase.status}');
  //         if (purchase.pendingCompletePurchase) {
  //           _inAppPurchase.completePurchase(purchase);
  //         }
  //         break;
  //       default:
  //         break;
  //     }
  //   }

  //   // Only set ads removed if store confirms the purchase
  //   if (foundNoAdsPurchase) {
  //     if (!_adsRemoved) {
  //       debugPrint('Setting ads removed to true based on store confirmation');
  //       _updateAdsRemoved(true);
  //     }
  //   }
  //   // Note: We don't clear _adsRemoved here if no purchase found,
  //   // because this could be called for other purchases or during normal purchase flow.
  //   // The verification logic in _verifyPurchaseStatus handles clearing stale data.
  // }

  Future<void> _updateAdsRemoved(bool value) async {
    if (_adsRemoved == value) return;
    setState(() {
      _adsRemoved = value;
      if (value) {
        _rewardedAd?.dispose();
        _rewardedAd = null;
      }
    });
    await _prefs?.setBool(noAdsPrefsKey, value);

    if (!value) {
      _loadRewardedAd();
    }
  }

  Future<void> _saveHistory() async {
    if (_prefs == null) return;
    // Normalize list lengths
    final maxLen = translationHistory.length;
    void padTo<T>(List<T?> list) { while (list.length < maxLen) list.add(null); }
    padTo(imageHistory);

    await _prefs!.setStringList('translationHistory', translationHistory);
    // Safely encode images - if encoding fails for any image, save empty string to maintain list alignment
    await _prefs!.setStringList('imageHistory', imageHistory.map((b) {
      if (b == null) return '';
      try {
        return base64Encode(b);
      } catch (e) {
        debugPrint('Error encoding image for history: $e');
        return ''; // Save empty string to maintain list alignment
      }
    }).toList());
    await _prefs!.setStringList('favorites', favorites.map((i) => i.toString()).toList());
  }
  void _loadRewardedAd() {
    if (_adsRemoved) return;
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


  Future<void> _addHistoryEntry({required String text, Uint8List? imageBytes}) async {
    translationHistory.add(text);
    imageHistory.add(imageBytes);
    await _saveHistory();
  }

  void _clearHistory() {
    setState(() {
      translationHistory.clear();
      imageHistory.clear();
      favorites.clear();
    });
    _saveHistory();
  }

  void _deleteHistoryEntry(int index) {
    if (index >= 0 && index < translationHistory.length) {
      setState(() {
        translationHistory.removeAt(index);
        if (index < imageHistory.length) {
          imageHistory.removeAt(index);
        }
        // Remove favorite if it exists, and adjust indices for entries after the deleted one
        favorites.remove(index);
        // Adjust favorite indices for entries after the deleted one
        final adjustedFavorites = <int>{};
        for (final favIndex in favorites) {
          if (favIndex > index) {
            adjustedFavorites.add(favIndex - 1);
          } else {
            adjustedFavorites.add(favIndex);
          }
        }
        favorites = adjustedFavorites;
      });
      _saveHistory();
    }
  }

  void _toggleFavorite(int index) {
    setState(() {
      if (favorites.contains(index)) {
        favorites.remove(index);
      } else {
        favorites.add(index);
      }
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
    // Check if we need to show the ad prompt (2 consecutive no-cat responses)
    final shouldPromptForAd = _consecutiveNoCatCount >= 3 && !_adsRemoved;

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
      
      // If we should prompt for ad, show dialog first
      if (shouldPromptForAd) {
        final shouldProceed = await _showNoCatAdPrompt();
        if (!shouldProceed) {
          // User declined, delete the image
          setState(() {
            _pickedImageBytes = null;
          });
          return;
        }
        // User accepted, show ad then evaluate
        // Reset the counter since they watched the ad
        _consecutiveNoCatCount = 0;
        await _saveNoCatCount();
        await _showRewardedAdIfAvailable();
      }
      
      await evaluateImage();
      return;
    }

    try {
      // Always take the picture first
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      setState(() {
        _pickedImageBytes = bytes;
        _outputText = null;
      });

      // If we should prompt for ad, show dialog now
      if (shouldPromptForAd) {
        final shouldProceed = await _showNoCatAdPrompt();
        if (!shouldProceed) {
          // User declined, delete the image
          setState(() {
            _pickedImageBytes = null;
          });
          return;
        }
        // User accepted, show ad then evaluate
        // Reset the counter since they watched the ad
        _consecutiveNoCatCount = 0;
        await _saveNoCatCount();
        await _showRewardedAdIfAvailable();
      }

      await evaluateImage();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error taking photo.')));
    }
  }

  /// Handles picking an image from gallery, showing ad prompt if needed, and translating
  Future<void> _onSelectImageAndTranslate() async {
    final shouldPromptForAd = _consecutiveNoCatCount >= 3 && !_adsRemoved;
    final bytes = await pickImageFromGallery();
    if (bytes == null) return;
    setState(() {
      _pickedImageBytes = bytes;
      _outputText = null;
    });
    if (shouldPromptForAd) {
      final shouldProceed = await _showNoCatAdPrompt();
      if (!shouldProceed) {
        // User declined, delete the image
        setState(() {
          _pickedImageBytes = null;
        });
        return;
      }
      // User accepted, show ad then evaluate
      // Reset the counter since they watched the ad
      _consecutiveNoCatCount = 0;
      await _saveNoCatCount();
      await _showRewardedAdIfAvailable();
    }
    await evaluateImage();
  }

  Future<bool> _showNoCatAdPrompt() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark
              ? const Color(0xFF1E293B)
              : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Watch Ad to Translate',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'No-cat translations cost CPU time. Watch a quick ad to translate?',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Watch Ad',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
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
        // prompt removed
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
          // Cat detected - reset the consecutive no-cat count
          _consecutiveNoCatCount = 0;
          await _saveNoCatCount();
          
          await _addHistoryEntry(text: text, imageBytes: _pickedImageBytes);

          // Show ad on every other translation, starting with the second (no ad on first)
          if (!_adsRemoved && translationHistory.length > 1 && translationHistory.length % 2 == 1) {
            await _showRewardedAdIfAvailable();
          }
        } else {
          // No cat detected - increment the consecutive count
          _consecutiveNoCatCount++;
          await _saveNoCatCount();
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
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              CatGptLogo(size: 28, isDark: widget.isDarkMode),
              const SizedBox(width: 10),
              Text(
                'CatGPT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    isDarkMode: widget.isDarkMode,
                    onThemeChanged: widget.onThemeChanged,
                    onClearHistory: _clearHistory,
                    adsRemoved: _adsRemoved,
                    onAdsStatusChanged: _updateAdsRemoved,
                  ),
                ),
              );
            },
              icon: Icon(
                Icons.settings_rounded,
                color: theme.colorScheme.onSurface,
              ),
            tooltip: 'Settings',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // Main content with adjusted spacing
                Expanded(child: _buildBody()),
              ],
            ),
          ),

          // Global analyzing/loading overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onTakePhoto,
                  borderRadius: BorderRadius.circular(40),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            )
                  : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E293B)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                _buildNavItem(
                  context,
                  icon: Icons.home_rounded,
                  activeIcon: Icons.home_filled,
                  label: 'Home',
                  index: 0,
                  theme: theme,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.camera_alt_outlined,
                  activeIcon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  index: 1,
                  theme: theme,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history_rounded,
                  label: 'History',
                  index: 2,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 1) {
      // Camera mode - layout preview vertically
      return Column(
        children: [
          Expanded(child: _buildCameraPreview()),
        ],
      );
    } else {
      // Other tabs: render as before
      return _currentIndex == 0
          ? _HomePageContent(
              onOpenCamera: () => setState(() {
                _currentIndex = 1;
                _outputText = null;
              }),
              onOpenHistory: () => setState(() {
                _currentIndex = 2;
                _outputText = null;
              }),
              onUploadAndTranslate: _onSelectImageAndTranslate,
              onTakePhotoAndTranslate: _onTakePhoto,
              recentTranslations: translationHistory,
              recentImages: imageHistory,
            )
          : HistoryPage(
              translationHistory: translationHistory,
              imageHistory: imageHistory,
              favorites: favorites,
              onDeleteEntry: _deleteHistoryEntry,
              onToggleFavorite: _toggleFavorite,
            );
    }
  }

  Widget _buildCameraPreview() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? theme.colorScheme.surfaceVariant : Colors.black;
    final mediaPadding = MediaQuery.of(context).padding;
    
    // Small offset at the top for the AppBar and logo (40% of full gap)
    final double topBarGap = (mediaPadding.top + kToolbarHeight + 16) * 0.40;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen camera preview (slightly offset downwards, extends to bottom behind navbar)
        Positioned(
          top: topBarGap,
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildMainCameraContent(theme, isDark, bg),
        ),

        // Result overlay when there's output text
        if (_outputText != null) _buildResultOverlay(theme),

        // Top overlay: select image button (overlays camera preview)
        if (!kIsWeb)
          Positioned(
            top: topBarGap - 20,  // Moved higher above the camera preview
            right: 12,
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
                onPressed: _onSelectImageAndTranslate,
                icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                tooltip: 'Select Image',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainCameraContent(ThemeData theme, bool isDark, Color bg) {
    // If we have a captured image, show it scaled to match the live preview
    if (_pickedImageBytes != null) {
      // If the camera controller is initialized we can mimic the preview's
      // cover-scaling by using the preview's reported dimensions.
      final previewSize = _cameraController?.value.previewSize;
      if (_cameraController != null && _cameraController!.value.isInitialized && previewSize != null) {
        // The plugin reports landscape sizes, swap to portrait dims.
        final double previewWidth = previewSize.height;
        final double previewHeight = previewSize.width;

        return Container(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: Image.memory(
                _pickedImageBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }

      // Fallback: contain the image if we can't determine preview size.
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
                onPressed: _onSelectImageAndTranslate,
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
    final mediaPadding = MediaQuery.of(context).padding;
    
    // Parse the output text to separate main text and reasoning
    final text = _outputText ?? '';
    final idx = text.indexOf('[');
    final mainText = idx == -1 ? text.trim() : text.substring(0, idx).trim();
    final reasoningText = idx != -1 && text.indexOf(']') > idx 
        ? text.substring(idx + 1, text.indexOf(']')).trim()
        : null;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 96.0 + mediaPadding.bottom + 24, // sits above the navbar with padding
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.98)
                  : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mainText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                  child: IconButton(
                    onPressed: () {
                      _resetCameraState();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
                if (reasoningText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reasoningText,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ],
                if (_pickedImageBytes != null && _outputText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
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
                        borderRadius: BorderRadius.circular(12),
                    child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Share',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: Colors.black.withOpacity(0.4),
              child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Analyzing...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isActive = _currentIndex == index;
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_currentIndex == 1) _resetCameraState();
              _currentIndex = index;
              _outputText = null;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 24,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  child: Text(label),
                ),
              ],
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
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final horizontalPadding = isWide ? 28.0 : 20.0;
        final topPadding = isWide ? 32.0 : 24.0;

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
            padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Centered logo banner with gradient background
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              theme.colorScheme.primary.withOpacity(0.15),
                              theme.colorScheme.tertiary.withOpacity(0.1),
                            ]
                          : [
                              theme.colorScheme.primary.withOpacity(0.08),
                              theme.colorScheme.tertiary.withOpacity(0.05),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CatGptLogo(size: isWide ? 64 : 56, isDark: isDark),
                        ),
                        const SizedBox(height: 16),
                      Text(
                        'CatGPT',
                        textAlign: TextAlign.center,
                          style: (isWide ? theme.textTheme.displaySmall : theme.textTheme.headlineLarge)
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                      Text(
                        'Translate your cat\'s vibes from a photo!',
                        textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 32),
                // Modern action buttons
                if (isWide)
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                            onPressed: onUploadAndTranslate,
                          icon: Icons.photo_library_rounded,
                          label: 'Upload Image',
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary,
                            ],
                          ),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context,
                            onPressed: onOpenCamera,
                          icon: Icons.camera_alt_rounded,
                          label: 'Open Camera',
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.secondary,
                              theme.colorScheme.primary,
                            ],
                          ),
                          theme: theme,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionButton(
                        context,
                          onPressed: onUploadAndTranslate,
                        icon: Icons.photo_library_rounded,
                        label: 'Upload Image',
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                        ),
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildActionButton(
                        context,
                          onPressed: onOpenCamera,
                        icon: Icons.camera_alt_rounded,
                        label: 'Open Camera',
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.secondary,
                            theme.colorScheme.primary,
                          ],
                        ),
                        theme: theme,
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
                if (hasRecent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onOpenHistory,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          'View all',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...recentItems.asMap().entries.map((entry) {
                    final itemIndex = entry.key;
                    final idx = entry.value;
                    final text = recentTranslations[idx];
                    final img = idx < recentImages.length ? recentImages[idx] : null;
                    final isEven = itemIndex % 2 == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B).withOpacity(1.0),
                                  const Color(0xFF1E293B).withOpacity(0.85),
                                ]
                              : [
                                  Colors.white.withOpacity(0.98),
                                  Colors.white.withOpacity(0.92),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark 
                                ? (isEven ? 0.12 : 0.15)
                                : (isEven ? 0.08 : 0.12),
                            ),
                            blurRadius: 10,
                            offset: Offset(0, isEven ? 4 : 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onOpenHistory,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                                  width: 56,
                                  height: 56,
                            decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              image: img != null
                                        ? DecorationImage(
                                            image: MemoryImage(img),
                                            fit: BoxFit.cover,
                                          )
                                  : null,
                            ),
                            child: img != null 
                                ? null 
                                : Icon(
                                          Icons.pets_rounded,
                                          size: 28,
                                          color: theme.colorScheme.primary,
                                        ),
                                ),
                                const SizedBox(width: 16),
                          Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        text.length > 80 ? '${text.substring(0, 80)}...' : text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view full translation',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (img != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () async {
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
                                      icon: Icon(
                                  Icons.share_rounded,
                                        size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                              ),
                            ),
                        ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                if (!hasRecent) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No recent translations yet.\nTry uploading a photo or opening the camera!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required ThemeData theme,
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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
