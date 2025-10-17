import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:catspeak/widgets/catgpt_logo.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ADD BACK FOR ADS import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'camera_page.dart';
import 'history_page.dart';
import 'audio_page.dart';

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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Uint8List? _pickedImageBytes;
  Uint8List? _recordedAudioBytes;
  int _currentIndex = 1;
  String? _outputText;
  bool _isLoading = false;
  // ADD BACK FOR ADS BannerAd? _bannerAd;
  // ADD BACK FOR ADS bool _isBannerLoaded = false;
  // ADD BACK FOR ADS RewardedAd? _rewardedAd;

  List<String> translationHistory = [];
  List<Uint8List?> imageHistory = [];
  List<Uint8List?> audioHistory = [];

  final ImagePicker _picker = ImagePicker();
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndHistory();
    // ADD BACK FOR ADS _loadBannerAd();
    // ADD BACK FOR ADS _loadRewardedAd();
  }

  Future<void> _loadPrefsAndHistory() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final texts = _prefs!.getStringList('translationHistory') ?? [];
      final imagesB64 = _prefs!.getStringList('imageHistory') ?? [];
      final audiosB64 = _prefs!.getStringList('audioHistory') ?? [];
      
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
          audioHistory = audiosB64.map((s) {
            if (s.isEmpty) return null;
            try {
              return base64Decode(s);
            } catch (e) {
              debugPrint('Error decoding audio: $e');
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
    padTo(audioHistory);

    await _prefs!.setStringList('translationHistory', translationHistory);
    await _prefs!.setStringList('imageHistory', imageHistory.map((b) => b == null ? '' : base64Encode(b)).toList());
    await _prefs!.setStringList('audioHistory', audioHistory.map((b) => b == null ? '' : base64Encode(b)).toList());
  }
  // ADD BACK FOR ADS void _loadBannerAd() {
  // ADD BACK FOR ADS   final ad = BannerAd(
  // ADD BACK FOR ADS     size: AdSize.banner,
  // ADD BACK FOR ADS     adUnitId: const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111'),
  // ADD BACK FOR ADS     listener: BannerAdListener(
  // ADD BACK FOR ADS       onAdLoaded: (ad) => setState(() {
  // ADD BACK FOR ADS         _isBannerLoaded = true;
  // ADD BACK FOR ADS       }),
  // ADD BACK FOR ADS       onAdFailedToLoad: (ad, error) {
  // ADD BACK FOR ADS         ad.dispose();
  // ADD BACK FOR ADS       },
  // ADD BACK FOR ADS     ),
  // ADD BACK FOR ADS     request: const AdRequest(),
  // ADD BACK FOR ADS   );
  // ADD BACK FOR ADS   ad.load();
  // ADD BACK FOR ADS   _bannerAd = ad;
  // ADD BACK FOR ADS }

  // ADD BACK FOR ADS void _loadRewardedAd() {
  // ADD BACK FOR ADS   RewardedAd.load(
  // ADD BACK FOR ADS     adUnitId: const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-3940256099942544/5224354917'),
  // ADD BACK FOR ADS     request: const AdRequest(),
  // ADD BACK FOR ADS     rewardedAdLoadCallback: RewardedAdLoadCallback(
  // ADD BACK FOR ADS       onAdLoaded: (ad) {
  // ADD BACK FOR ADS         _rewardedAd = ad;
  // ADD BACK FOR ADS       },
  // ADD BACK FOR ADS       onAdFailedToLoad: (error) {
  // ADD BACK FOR ADS         _rewardedAd = null;
  // ADD BACK FOR ADS       },
  // ADD BACK FOR ADS     ),
  // ADD BACK FOR ADS   );
  // ADD BACK FOR ADS }

  // ADD BACK FOR ADS Future<void> _showRewardedAdIfAvailable() async {
  // ADD BACK FOR ADS   final ad = _rewardedAd;
  // ADD BACK FOR ADS   if (ad == null) return;
  // ADD BACK FOR ADS   await ad.show(onUserEarnedReward: (ad, reward) {});
  // ADD BACK FOR ADS   ad.dispose();
  // ADD BACK FOR ADS   _rewardedAd = null;
  // ADD BACK FOR ADS   _loadRewardedAd();
  // ADD BACK FOR ADS }


  void _addHistoryEntry({required String text, Uint8List? imageBytes, Uint8List? audioBytes}) {
    translationHistory.add(text);
    imageHistory.add(imageBytes);
    audioHistory.add(audioBytes);
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
  }


  Future<void> evaluateImage() async {
    if (_pickedImageBytes == null) return;
    setState(() => _isLoading = true);

    try {
      const apiKey = 'AIzaSyAiV17lMotobdGjP9UydikjhgFRXCbzV9w';
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
                    "Analyze the subject'sbody language and interpret it's feelings into a dialogue-like phrase that is short, but still contains substance (no one word phrases). The subject should be a cat. If the subject is not a cat, simply state 'No cat detected!'. Additionally, add reasoning for the decision in short phrases, encapsulated in []. Provide exactly 3 reasons, all enclosed in the same braces. Your response should only contain one set of [] total. Example Phrase: The sun feels good on my belly, I think I'll stay here. [rolled over, eyes closed, sunshine]"
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
          _addHistoryEntry(text: text, imageBytes: _pickedImageBytes, audioBytes: null);
        });
        // ADD BACK FOR ADS await _showRewardedAdIfAvailable();
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

  Future<Uint8List?> recordAudio(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      setState(() {
        _recordedAudioBytes = bytes;
        _outputText = null;
      });
      return bytes;
    } catch (e) {
      debugPrint('recordAudio error: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording audio: $e')),
      );
    }
    return null;
  }

  Future<void> evaluateAudio() async {
    if (_recordedAudioBytes == null) return;
    setState(() => _isLoading = true);

    try {
      const apiKey = 'AIzaSyAiV17lMotobdGjP9UydikjhgFRXCbzV9w';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent?key=$apiKey');

      final headers = {'Content-Type': 'application/json'};
      final base64Audio = base64Encode(_recordedAudioBytes!);

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Analyze this cat's meow and interpret it's feelings into a dialogue-like phrase that is short, but still contains substance (no one word phrases). Additionally, add reasoning for the decision in short phrases, encapsulated in []. Provide exactly 3 reasons. Example: I'm hungry and you're taking too long with my dinner! [high pitched meow, persistent tone, following you around]. Your response must match exactly the syntax of this example, and should contain no more substance than requested"
              },
              {
                "inline_data": {
                  "mime_type": "audio/m4a",
                  "data": base64Audio
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
          _addHistoryEntry(text: text, imageBytes: null, audioBytes: _recordedAudioBytes);
        });
        // ADD BACK FOR ADS await _showRewardedAdIfAvailable();
      } else {
        debugPrint('API error ${response.statusCode}: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('API Error: ${response.statusCode}')));
      }
    } catch (e) {
      debugPrint('evaluateAudio error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error analyzing audio.')));
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
          SafeArea(child: Column(
            children: [
              Expanded(child: _buildBody()),
              // ADD BACK FOR ADS if (_isBannerLoaded && _bannerAd != null)
              // ADD BACK FOR ADS   SizedBox(
              // ADD BACK FOR ADS     width: _bannerAd!.size.width.toDouble(),
              // ADD BACK FOR ADS     height: _bannerAd!.size.height.toDouble(),
              // ADD BACK FOR ADS     child: AdWidget(ad: _bannerAd!),
              // ADD BACK FOR ADS   ),
            ],
          )),
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
              : _currentIndex == 2
                  ? null // AudioPage manages its own recording controls
                  : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
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
                  Icons.mic_rounded,
                  size: 28,
                  color: _currentIndex == 2
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () => setState(() {
                  _currentIndex = 2;
                  // Clear cross-tab artifacts
                  _outputText = null;
                }),
                tooltip: 'Audio',
              ),
              IconButton(
                icon: Icon(
                  Icons.history_rounded,
                  size: 28,
                  color: _currentIndex == 3
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () => setState(() {
                  _currentIndex = 3;
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
              onOpenAudio: () => setState(() {
                _currentIndex = 2;
                _outputText = null;
              }),
              onOpenHistory: () => setState(() {
                _currentIndex = 3;
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
              recentAudios: audioHistory,
            )
          : _currentIndex == 1
              ? CameraPage(
                  pickedImageBytes: _pickedImageBytes,
                  outputText: _outputText,
                  pickImage: pickImage,
                  evaluateImage: evaluateImage,
                  onImageCaptured: (Uint8List bytes) {
                    setState(() {
                      _pickedImageBytes = bytes;
                    });
                  },
                )
              : _currentIndex == 2
                  ? AudioPage(
                      recordedAudioBytes: _recordedAudioBytes,
                      outputText: _outputText,
                      recordAudio: recordAudio,
                      evaluateAudio: evaluateAudio,
                    )
                  : HistoryPage(
                      translationHistory: translationHistory,
                      imageHistory: imageHistory,
                      audioHistory: audioHistory,
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
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onUploadAndTranslate;
  final Future<void> Function() onTakePhotoAndTranslate;
  final List<String> recentTranslations;
  final List<Uint8List?> recentImages;
  final List<Uint8List?> recentAudios;

  const _HomePageContent({
    required this.onOpenCamera,
    required this.onOpenAudio,
    required this.onOpenHistory,
    required this.onUploadAndTranslate,
    required this.onTakePhotoAndTranslate,
    required this.recentTranslations,
    required this.recentImages,
    required this.recentAudios,
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
        color: Colors.deepPurple,
        icon: Icons.mic_rounded,
        title: 'Record Meow',
        subtitle: 'Capture 10s and translate',
        onTap: onOpenAudio,
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
                    final aud = idx < recentAudios.length ? recentAudios[idx] : null;
                    final isAudio = aud != null && (aud.isNotEmpty);
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
                              color: isAudio 
                                  ? Colors.deepPurple.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.12) 
                                  : Colors.blueGrey.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              image: !isAudio && img != null
                                  ? DecorationImage(image: MemoryImage(img), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (!isAudio && img != null) 
                                ? null 
                                : Icon(
                                    isAudio ? Icons.mic_rounded : Icons.pets, 
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
