import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/share_service.dart';

class HistoryPage extends StatefulWidget {
  final List<String> translationHistory;
  final List<Uint8List?> imageHistory;
  final Set<int> favorites;
  final Function(int) onDeleteEntry;
  final Function(int) onToggleFavorite;
  final bool isPremium;
  final VoidCallback onPurchasePremium;

  const HistoryPage({
    super.key,
    required this.translationHistory,
    required this.imageHistory,
    required this.favorites,
    required this.onDeleteEntry,
    required this.onToggleFavorite,
    required this.isPremium,
    required this.onPurchasePremium,
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
      var indices = favoriteIndices.where((idx) => idx >= 0 && idx < widget.translationHistory.length).toList();
      // For free users, limit to last 3 favorites
      if (!widget.isPremium && indices.length > 3) {
        indices = indices.take(3).toList();
      }
      return indices;
    } else {
      // Return all indices in reverse order
      var indices = List.generate(widget.translationHistory.length, (i) => widget.translationHistory.length - 1 - i);
      // For free users, limit to last 3 translations
      if (!widget.isPremium && indices.length > 3) {
        indices = indices.take(3).toList();
      }
      return indices;
    }
  }
  
  int _getHiddenCount() {
    if (widget.isPremium) return 0;
    final total = _filterMode == 'Favorites' ? widget.favorites.length : widget.translationHistory.length;
    return total > 3 ? total - 3 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndices = _getFilteredIndices();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (widget.translationHistory.isEmpty || filteredIndices.isEmpty) {
      return Column(
        children: [
          _buildFilterDropdown(),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.all(20),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _filterMode == 'Favorites'
                            ? Icons.favorite_border_rounded
                            : Icons.history_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filterMode == 'Favorites'
                          ? "No favorites yet"
                          : "No history yet",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _filterMode == 'Favorites'
                          ? "Start favoriting translations to see them here"
                          : "Your translation history will appear here",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
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
                  itemCount: filteredIndices.length + (_getHiddenCount() > 0 ? 1 : 0), // Add 1 for premium prompt if needed
                  itemBuilder: (context, index) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    
                    // Show premium prompt at the end if there are hidden items
                    if (index == filteredIndices.length && _getHiddenCount() > 0) {
                      return _buildPremiumPrompt(context, theme, isDark);
                    }
                    final reverseIndex = filteredIndices[index];

                    final safeImageIndex = reverseIndex < widget.imageHistory.length ? reverseIndex : -1;

                    final translation = widget.translationHistory[reverseIndex];
                    final imageBytes = safeImageIndex >= 0 ? widget.imageHistory[safeImageIndex] : null;
                    
                    return GestureDetector(
                      onTap: () => _showDetail(context, translation, imageBytes),
                      child: Container(
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
                                  ? (reverseIndex % 2 == 0 ? 0.12 : 0.15)
                                  : (reverseIndex % 2 == 0 ? 0.08 : 0.12),
                              ),
                              blurRadius: 10,
                              offset: Offset(0, reverseIndex % 2 == 0 ? 4 : 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showDetail(context, translation, imageBytes),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: tileSide,
                                    height: tileSide,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: theme.colorScheme.primary.withOpacity(0.1),
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
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: imageBytes != null
                                          ? Image.memory(
                                              imageBytes,
                                              width: tileSide,
                                              height: tileSide,
                                              fit: BoxFit.cover,
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.pets_rounded,
                                                size: 36,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _shortPreview(translation),
                                          style: TextStyle(
                                            fontSize: isWide ? 17 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _previewReason(translation),
                                          style: TextStyle(
                                            fontSize: isWide ? 13 : 12,
                                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: widget.favorites.contains(reverseIndex)
                                              ? Colors.red.withOpacity(0.1)
                                              : theme.colorScheme.onSurface.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            widget.onToggleFavorite(reverseIndex);
                                          },
                                          icon: Icon(
                                            widget.favorites.contains(reverseIndex)
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            size: 20,
                                            color: widget.favorites.contains(reverseIndex)
                                                ? Colors.red
                                                : theme.colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                                title: Text(
                                                  'Delete Entry',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                content: const Text(
                                                  'Are you sure you want to delete this entry?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(),
                                                    child: Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          theme.colorScheme.error,
                                                          theme.colorScheme.error.withOpacity(0.8),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        widget.onDeleteEntry(reverseIndex);
                                                        Navigator.of(ctx).pop();
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.transparent,
                                                        shadowColor: Colors.transparent,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: theme.colorScheme.error,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _filterMode,
              underline: Container(),
              isExpanded: true,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
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
      return 'Reasoning: $inside';
    }
    return 'Tap to view full analysis';
  }

  void _showDetail(BuildContext context, String translation, Uint8List? image) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.pets_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          image,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      translation,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (image != null)
                          Expanded(
                            child: Container(
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
                                onPressed: () async {
                                  try {
                                    await ShareService.shareInstagramStyle(
                                      imageBytes: image,
                                      text: translation,
                                      context: context,
                                      isPremium: widget.isPremium,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error sharing: ${e.toString()}'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.share_rounded, color: Colors.white),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                        if (image != null) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withOpacity(0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPremiumPrompt(BuildContext context, ThemeData theme, bool isDark) {
    final hiddenCount = _getHiddenCount();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.tertiary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPurchasePremium,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Paw icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.pets_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock Full History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You have $hiddenCount more translation${hiddenCount == 1 ? '' : 's'} saved',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: widget.onPurchasePremium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.pets_rounded, size: 20),
                    label: const Text(
                      'Get CatGPT Premium',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Extended history • No watermarks • Premium captions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
