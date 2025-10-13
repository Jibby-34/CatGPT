import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:catspeak/widgets/catgpt_logo.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_page.dart';
import 'history_page.dart';
import 'audio_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Uint8List? _pickedImageBytes;
  Uint8List? _recordedAudioBytes;
  int _currentIndex = 1;
  String? _outputText;
  bool _isLoading = false;

  List<String> translationHistory = [];
  List<Uint8List?> imageHistory = [];
  List<Uint8List?> audioHistory = [];

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndHistory();
  }

  Future<void> _loadPrefsAndHistory() async {
    _prefs = await SharedPreferences.getInstance();
    final texts = _prefs!.getStringList('translationHistory') ?? [];
    final imagesB64 = _prefs!.getStringList('imageHistory') ?? [];
    final audiosB64 = _prefs!.getStringList('audioHistory') ?? [];
    setState(() {
      translationHistory = texts;
      imageHistory = imagesB64.map((s) => s.isEmpty ? null : base64Decode(s)).toList();
      audioHistory = audiosB64.map((s) => s.isEmpty ? null : base64Decode(s)).toList();
    });
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

  Future<void> _onRecordAudio() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // Navigate to Audio tab and let AudioPage manage recording
        setState(() {
          _currentIndex = 2;
          _recordedAudioBytes = null;
          _outputText = null;
        });
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
                    "Analyze this cat's body language and interpret it's feelings into a dialogue-like phrase that is short, but still contains substance (no one word phrases). Additionally, add reasoning for the decision in short phrases, encapsulated in []. Provide exactly 3 reasons. Example: The sun feels good on my belly, I think I'll stay here. [rolled over, eyes closed, sunshine]. Your response must match exactly the syntax of this example, and should contain no more substance than requested"
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CatGptLogo(size: 35),
            SizedBox(width: 8),
            Text('CatGPT'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Settings coming soon')));
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(child: _buildBody()),
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
        color: Colors.white,
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
                      : Colors.black54,
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
                      : Colors.black54,
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
                      : Colors.black54,
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
                      : Colors.black54,
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
          ? const _HomePageContent()
          : _currentIndex == 1
              ? CameraPage(
                  pickedImageBytes: _pickedImageBytes,
                  outputText: _outputText,
                  pickImage: pickImage,
                  evaluateImage: evaluateImage,
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
  const _HomePageContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CatGptLogo(size: 82),
              const SizedBox(height: 18),
              Text(
                'CatGPT',
                style: theme.textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Translate your cat\'s vibes into short, sassy phrases. Take a photo and watch the magic.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // This will be handled by the parent widget
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('Start Translating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
