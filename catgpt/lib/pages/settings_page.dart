import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
import 'tutorial_page.dart';
// import '../constants/purchase_constants.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final VoidCallback onClearHistory;
  final bool adsRemoved;
  final ValueChanged<bool> onAdsStatusChanged;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onClearHistory,
    required this.adsRemoved,
    required this.onAdsStatusChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;
  late bool _adsRemoved;
  // final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  // StreamSubscription<List<PurchaseDetails>>? _subscription;
  // ProductDetails? _noAdsProduct;
  // bool _isStoreAvailable = false;
  // bool _isLoadingProducts = false;
  // bool _purchasePending = false;
  // String? _purchaseError;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _adsRemoved = widget.adsRemoved;
    // _subscription = _inAppPurchase.purchaseStream.listen(
    //   _onPurchaseUpdated,
    //   onError: _handlePurchaseError,
    // );
    // _initStoreInfo();
  }

  @override
  void dispose() {
    // _subscription?.cancel();
    super.dispose();
  }

  // void _handlePurchaseError(Object error) {
  //   if (!mounted) return;
  //   setState(() {
  //     _purchaseError = error.toString();
  //     _purchasePending = false;
  //   });
  // }

  // Future<void> _initStoreInfo() async {
  //   setState(() {
  //     _isLoadingProducts = true;
  //     _purchaseError = null;
  //   });

  //   final available = await _inAppPurchase.isAvailable();
  //   if (!mounted) return;
  //   setState(() {
  //     _isStoreAvailable = available;
  //   });
  //   if (!available) {
  //     setState(() => _isLoadingProducts = false);
  //     return;
  //   }

  //   final response = await _inAppPurchase.queryProductDetails({noAdsProductId});
  //   if (!mounted) return;
  //   setState(() {
  //     _noAdsProduct = response.productDetails.isNotEmpty
  //         ? response.productDetails.first
  //         : null;
  //     _purchaseError = response.error?.message;
  //     _isLoadingProducts = false;
  //   });
  // }

  // Future<void> _markNoAdsPurchased() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool(noAdsPrefsKey, true);
  //   if (!mounted) return;
  //   setState(() {
  //     _adsRemoved = true;
  //     _purchasePending = false;
  //   });
  //   widget.onAdsStatusChanged(true);
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('Ads removed. Thank you!'),
  //       duration: Duration(seconds: 2),
  //     ),
  //   );
  // }

  // void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
  //   for (final purchase in purchases) {
  //     if (purchase.productID != noAdsProductId) continue;

  //     switch (purchase.status) {
  //       case PurchaseStatus.purchased:
  //       case PurchaseStatus.restored:
  //         _markNoAdsPurchased();
  //         break;
  //       case PurchaseStatus.pending:
  //         setState(() => _purchasePending = true);
  //         break;
  //       case PurchaseStatus.canceled:
  //         setState(() {
  //           _purchasePending = false;
  //           _purchaseError = 'Purchase canceled';
  //         });
  //         break;
  //       case PurchaseStatus.error:
  //         setState(() {
  //           _purchasePending = false;
  //           _purchaseError = purchase.error?.message ?? 'Purchase failed';
  //         });
  //         break;
  //       default:
  //         break;
  //     }

  //     if (purchase.pendingCompletePurchase) {
  //       _inAppPurchase.completePurchase(purchase);
  //     }
  //   }
  // }

  // Future<void> _buyNoAds() async {
  //   if (_adsRemoved) return;
  //   final product = _noAdsProduct;
  //   if (product == null) {
  //     setState(() => _purchaseError = 'No Ads product unavailable');
  //     return;
  //   }
  //   setState(() {
  //     _purchasePending = true;
  //     _purchaseError = null;
  //   });
  //   final purchaseParam = PurchaseParam(productDetails: product);
  //   await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  // }

  // Future<void> _restorePurchases() async {
  //   setState(() {
  //     _purchasePending = true;
  //     _purchaseError = null;
  //   });
  //   await _inAppPurchase.restorePurchases();
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            // Tutorial Section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Help & Support',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            _buildModernCard(
              context,
              theme: theme,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TutorialPage(),
                  ),
                );
              },
              icon: Icons.school_rounded,
              iconColor: theme.colorScheme.primary,
              title: 'Tutorial',
              subtitle: 'Learn how to use CatGPT',
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
            // Appearance Section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Appearance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            _buildModernCard(
              context,
              theme: theme,
              isDark: isDark,
              onTap: null,
              icon: _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: theme.colorScheme.primary,
              title: 'Dark Mode',
              subtitle: _isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkMode', value);
                  setState(() => _isDarkMode = value);
                  widget.onThemeChanged(value);
                },
              ),
            ),
            const SizedBox(height: 32),
            // Data Section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Data Management',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            _buildModernCard(
              context,
              theme: theme,
              isDark: isDark,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: Text(
                      'Clear History',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to clear all history? This action cannot be undone.',
                      style: TextStyle(
                        height: 1.5,
                      ),
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
                            widget.onClearHistory();
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('History cleared'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: Icons.delete_outline_rounded,
              iconColor: theme.colorScheme.error,
              title: 'Clear History',
              subtitle: 'Delete all translation history',
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard(
    BuildContext context, {
    required ThemeData theme,
    required bool isDark,
    required VoidCallback? onTap,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
