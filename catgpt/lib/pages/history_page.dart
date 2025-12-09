import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/share_service.dart';

class HistoryPage extends StatefulWidget {
  final List<String> translationHistory;
  final List<Uint8List?> imageHistory;
  final Set<int> favorites;
  final Function(int) onDeleteEntry;
  final Function(int) onToggleFavorite;

  const HistoryPage({
    super.key,
    required this.translationHistory,
    required this.imageHistory,
    required this.favorites,
    required this.onDeleteEntry,
    required this.onToggleFavorite,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;
  bool _isScrollable = false;
  String _filterMode = 'All History'; // 'All History' or 'Favorites'

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

  List<int> _getFilteredIndices() {
    if (_filterMode == 'Favorites') {
      // Return indices that are in favorites, in reverse order (newest first)
      final favoriteIndices = widget.favorites.toList()..sort((a, b) => b.compareTo(a));
      return favoriteIndices.where((idx) => idx >= 0 && idx < widget.translationHistory.length).toList();
    } else {
      // Return all indices in reverse order
      return List.generate(widget.translationHistory.length, (i) => widget.translationHistory.length - 1 - i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndices = _getFilteredIndices();

    if (widget.translationHistory.isEmpty || filteredIndices.isEmpty) {
      return Column(
        children: [
          _buildFilterDropdown(),
          Expanded(
            child: Center(
              child: Text(
                _filterMode == 'Favorites' 
                    ? "❤️ No favorites yet..."
                    : "📜 No history yet...",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final horizontalPadding = isWide ? 28.0 : 12.0;
        final tileSide = isWide ? 120.0 : 92.0;

        return Column(
          children: [
            _buildFilterDropdown(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 
                  12, 
                  horizontalPadding, 
                  12
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredIndices.length,
                  itemBuilder: (context, index) {
                    final reverseIndex = filteredIndices[index];

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
                              InkWell(
                                onTap: () {
                                  widget.onToggleFavorite(reverseIndex);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    widget.favorites.contains(reverseIndex)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: widget.favorites.contains(reverseIndex)
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Entry'),
                                      content: const Text('Are you sure you want to delete this entry?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            widget.onDeleteEntry(reverseIndex);
                                            Navigator.of(ctx).pop();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
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

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 4),
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _filterMode,
            underline: Container(),
            items: const [
              DropdownMenuItem(
                value: 'All History',
                child: Text('All History'),
              ),
              DropdownMenuItem(
                value: 'Favorites',
                child: Text('Favorites'),
              ),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _filterMode = newValue;
                });
              }
            },
          ),
        ],
      ),
    );
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
