import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const CatTranslatorApp());
}

class CatTranslatorApp extends StatelessWidget {
  const CatTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatSpeak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
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

class _HomePageState extends State<HomePage> {
  Uint8List? _pickedImageBytes;
  int _currentIndex = 1;
  
  // ⭐ NEW: Store output text from API
  String? _outputText;

  Future<void> _onImageUpload() async {
    final imageBytes = await pickImage();
    if (imageBytes == null) return;

    setState(() {
      _pickedImageBytes = imageBytes;
      _outputText = null; // reset before evaluating
    });

    await evaluateImage(); // ⭐ Make sure we await this
  }

  Future<Uint8List?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        return await pickedFile.readAsBytes();
      } else {
        final file = File(pickedFile.path);
        return await file.readAsBytes();
      }
    }
    return null;
  }

  Future<void> evaluateImage() async {
    if (_pickedImageBytes == null) {
      print("❌ No image selected");
      return;
    }

    // PLEASE REMOVE BEFORE PUSH
    const apiKey = 'AIzaSyAiV17lMotobdGjP9UydikjhgFRXCbzV9w';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent?key=$apiKey',
    );

    final headers = {
      'Content-Type': 'application/json',
    };

    // Encode image as base64
    final base64Image = base64Encode(_pickedImageBytes!);

    // 👇 Build request with text + image
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "text":
                  "Analyze this cat's body language and interpret it's feelings into a dialogue-like phrase. Additionally, add reasoning for the decision in short phrases, encapsulated in []. An example phrase: Feed me you stupid human! [eyes slit, tail straight, showing trust]"
            },
            {
              "inline_data": {
                "mime_type": "image/jpeg", // or "image/png" if PNG
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
      final text = data["candidates"][0]["content"]["parts"][0]["text"];
      print("💡 Gemini says: $text");
      setState(() {
        _outputText = text;
      });
    } else {
      print("❌ Error: ${response.statusCode} - ${response.body}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CatSpeak"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image preview or placeholder
            Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: _pickedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_pickedImageBytes!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.pets, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Upload button
            ElevatedButton.icon(
              onPressed: _onImageUpload,
              icon: const Icon(Icons.upload),
              label: const Text("Upload Cat Photo"),
            ),

            // ⭐ NEW: Output text box — only appears if _outputText != null
            if (_outputText != null) ...[
              const SizedBox(height: 20),
              Container(
                width: 300,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal, width: 1.5),
                ),
                child: Text(
                  _outputText!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Camera"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
