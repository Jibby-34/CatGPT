import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/share_service.dart';

class HistoryPage extends StatefulWidget {
  final List<String> translationHistory;
  final List<Uint8List?> imageHistory;
  final VoidCallback onClearHistory;

  const HistoryPage({
    super.key,
    required this.translationHistory,
    required this.imageHistory,
    required this.onClearHistory,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;
  bool _isScrollable = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollPosition);
    // Check initial scroll position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollPosition();
      _checkIfScrollable();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients) return;
    _checkIfScrollable();
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;
    if (isAtBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
      });
    }
  }

  void _checkIfScrollable() {
    if (!_scrollController.hasClients) return;
    final isScrollable = _scrollController.position.maxScrollExtent > 0;
    if (isScrollable != _isScrollable) {
      setState(() {
        _isScrollable = isScrollable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.translationHistory.isEmpty) {
      return const Center(
        child: Text(
          "📜 No history yet...",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final horizontalPadding = isWide ? 28.0 : 12.0;
        final tileSide = isWide ? 120.0 : 92.0;

        // Show button if: content doesn't fill screen OR user scrolled to bottom
        final shouldShowButton = widget.translationHistory.isNotEmpty && 
            (!_isScrollable || _isAtBottom);

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 
                  12, 
                  horizontalPadding, 
                  shouldShowButton ? 12 : 12
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.translationHistory.length,
                  itemBuilder: (context, index) {
                    final len = widget.translationHistory.length;
                    final reverseIndex = len - 1 - index;

                    final safeImageIndex = reverseIndex < widget.imageHistory.length ? reverseIndex : -1;

                    final translation = widget.translationHistory[reverseIndex];
                    final imageBytes = safeImageIndex >= 0 ? widget.imageHistory[safeImageIndex] : null;

                    return GestureDetector(
                      onTap: () => _showDetail(context, translation, imageBytes),
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
                                child: imageBytes != null
                                        ? Image.memory(imageBytes,
                                            width: tileSide, height: tileSide, fit: BoxFit.cover)
                                        : Container(
                                            width: tileSide,
                                            height: tileSide,
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
                                        Expanded(
                                          child: Text(
                                            _shortPreview(translation),
                                            style: TextStyle(
                                                fontSize: isWide ? 17 : 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _previewReason(translation),
                                      style: TextStyle(
                                          fontSize: isWide ? 14 : 13,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              if (imageBytes != null) ...[
                                InkWell(
                                  onTap: () async {
                                    try {
                                      await ShareService.shareInstagramStyle(
                                        imageBytes: imageBytes,
                                        text: translation,
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.share_rounded,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                Icons.chevron_right_rounded,
                                // Follow theme: use a white-ish icon in dark mode, keep muted dark color in light mode
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Clear history button - appears at bottom when appropriate
            if (shouldShowButton)
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 20),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear History'),
                          content: const Text('Are you sure you want to clear all history? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                widget.onClearHistory();
                                Navigator.of(ctx).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Clear History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _shortPreview(String text) {
    final idx = text.indexOf('[');
    if (idx == -1) return text.length > 60 ? '${text.substring(0, 60)}…' : text;
    final p = text.substring(0, idx).trim();
    return p.length > 60 ? '${p.substring(0, 60)}…' : p;
  }

  String _previewReason(String text) {
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
                      child: Image.memory(image, height: 260, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    translation,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (image != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await ShareService.shareInstagramStyle(
                                imageBytes: image,
                                text: translation,
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
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
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
