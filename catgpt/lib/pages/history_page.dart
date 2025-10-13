import 'dart:typed_data';
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  final List<String> translationHistory;
  final List<Uint8List?> imageHistory;
  final List<Uint8List?> audioHistory;

  const HistoryPage({
    super.key,
    required this.translationHistory,
    required this.imageHistory,
    required this.audioHistory,
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
          final len = translationHistory.length;
          final reverseIndex = len - 1 - index;

          // Guard against length mismatches between lists
          final safeImageIndex = reverseIndex < imageHistory.length ? reverseIndex : -1;
          final safeAudioIndex = reverseIndex < audioHistory.length ? reverseIndex : -1;

          final translation = translationHistory[reverseIndex];
          final imageBytes = safeImageIndex >= 0 ? imageHistory[safeImageIndex] : null;
          final audioBytes = safeAudioIndex >= 0 ? audioHistory[safeAudioIndex] : null;
          final isAudio = audioBytes != null;

          return GestureDetector(
            onTap: () => _showDetail(context, translation, imageBytes, audioBytes),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: isAudio
                          ? Container(
                              width: 92,
                              height: 92,
                              color: Colors.blue[50],
                              child: const Icon(Icons.mic, size: 36, color: Colors.blue),
                            )
                          : imageBytes != null
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
                          Row(
                            children: [
                              if (isAudio)
                                const Icon(Icons.mic, size: 16, color: Colors.blue),
                              if (isAudio) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _shortPreview(translation),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
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

  void _showDetail(BuildContext context, String translation, Uint8List? image, Uint8List? audio) {
    final isAudio = audio != null;
    
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
                  if (isAudio)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, size: 64, color: Colors.blue),
                            SizedBox(height: 8),
                            Text(
                              'Audio Recording',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to play (coming soon)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(image, height: 260, fit: BoxFit.cover),
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
