// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CatTranslatorApp());
}

class CatTranslatorApp extends StatelessWidget {
  const CatTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CatGPT',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          secondary: Colors.tealAccent.shade700,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FF),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Uint8List? _pickedImageBytes;
  int _currentIndex = 1;
  String? _outputText;
  bool _isLoading = false;

  List<String> translationHistory = [];
  List<Uint8List?> imageHistory = [];

  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;
      if (kIsWeb) {
        return await pickedFile.readAsBytes();
      } else {
        final file = File(pickedFile.path);
        return await file.readAsBytes();
      }
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
      const apiKey = 'API KEY';
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
                    "Analyze this cat's body language and interpret it's feelings into a dialogue-like phrase that is short, but still contains substance (no one word phrases). Additionally, add reasoning for the decision in short phrases, encapsulated in []. the reasons should ONLY contain a single set of [], with one or two word reasons in a comma separated list. Provide exactly 3 reasons. An example phrase: Feed me you stupid human! [eyes slit, tail straight, showing trust]"
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
        debugPrint("Gemini result: $text");

        setState(() {
          _outputText = text;
          translationHistory.add(text);
          imageHistory.add(_pickedImageBytes);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 22),
            const SizedBox(width: 8),
            Text('CatGPT',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
      bottomNavigationBar: BottomAppBar(
        color: Colors.white, // match scaffold background
        elevation: 0, // no shadow border
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
                onPressed: () => setState(() => _currentIndex = 0),
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
                onPressed: () => setState(() => _currentIndex = 1),
                tooltip: 'Camera',
              ),
              IconButton(
                icon: Icon(
                  Icons.history_rounded,
                  size: 28,
                  color: _currentIndex == 2
                      ? theme.colorScheme.primary
                      : Colors.black54,
                ),
                onPressed: () => setState(() => _currentIndex = 2),
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
              ? _buildCameraPage()
              : HistoryPage(
                  translationHistory: translationHistory,
                  imageHistory: imageHistory,
                ),
    );
  }

  Widget _buildCameraPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.9), const Color(0xFFEFF3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: _pickedImageBytes != null
                          ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.pets, size: 92, color: Colors.black26),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tap the camera button to take a photo'),
                      if (kIsWeb)
                        TextButton.icon(
                          onPressed: () async {
                            final bytes = await pickImage();
                            if (bytes == null) return;
                            setState(() => _pickedImageBytes = bytes);
                            await evaluateImage();
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _outputText != null
                        ? Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
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
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.pets, size: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _outputText!,
                                    style:
                                        const TextStyle(fontSize: 16, height: 1.35),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Copied to clipboard (mock)')));
                                  },
                                  icon: const Icon(Icons.copy_outlined),
                                  tooltip: 'Copy',
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
  const _HomePageContent({super.key});

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
              const Icon(Icons.pets, size: 82, color: Colors.black54),
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
                  final state = context.findAncestorStateOfType<_HomePageState>();
                  state?.setState(() => state._currentIndex = 1);
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

class HistoryPage extends StatelessWidget {
  final List<String> translationHistory;
  final List<Uint8List?> imageHistory;

  const HistoryPage({
    super.key,
    required this.translationHistory,
    required this.imageHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (translationHistory.isEmpty) {
      return const Center(
        child: Text(
          "📜 No history yet...",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: translationHistory.length,
        itemBuilder: (context, index) {
          final reverseIndex = translationHistory.length - 1 - index;
          final translation = translationHistory[reverseIndex];
          final imageBytes = imageHistory[reverseIndex];

          return GestureDetector(
            onTap: () => _showDetail(context, translation, imageBytes),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageBytes != null
                          ? Image.memory(imageBytes,
                              width: 92, height: 92, fit: BoxFit.cover)
                          : Container(
                              width: 92,
                              height: 92,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 36),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shortPreview(translation),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _previewReason(translation),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.black38),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _shortPreview(String text) {
    final idx = text.indexOf('[');
    if (idx == -1) return text.length > 60 ? '${text.substring(0, 60)}…' : text;
    final p = text.substring(0, idx).trim();
    return p.length > 60 ? '${p.substring(0, 60)}…' : p;
  }

  static String _previewReason(String text) {
    final start = text.indexOf('[');
    final end = text.indexOf(']');
    if (start != -1 && end != -1 && end > start) {
      final inside = text.substring(start + 1, end);
      return 'Reasons: $inside';
    }
    return 'Tap to view full analysis';
  }

  void _showDetail(BuildContext context, String translation, Uint8List? image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          Image.memory(image, height: 260, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    translation,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
