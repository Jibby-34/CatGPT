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
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            // Tutorial Section
            Text(
              'Help',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Tutorial',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Learn how to use CatGPT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TutorialPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Appearance Section
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Dark Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isDarkMode
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
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
            ),
            const SizedBox(height: 24),
            // Data Section
            Text(
              'Data',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Clear History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Delete all translation history',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('History cleared'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
