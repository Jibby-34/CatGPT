# TestFlight In-App Purchase Verification Checklist

## Current Configuration

Based on your codebase, here are your current IDs:

- **Bundle ID**: `com.blinklabs.catgpt`
- **Product ID**: `com.blinklabs.catgpt.remove_ads`
- **Product Type**: Non-Consumable

## Critical Items to Verify in App Store Connect

### 1. Bundle Identifier Match ✅
- [ ] Go to App Store Connect → Your App → App Information
- [ ] Verify the **Bundle ID** is exactly: `com.blinklabs.catgpt`
- [ ] This must match exactly what's in your Xcode project (`ios/Runner.xcodeproj/project.pbxproj`)

### 2. In-App Purchase Product Configuration ✅
- [ ] Go to App Store Connect → Your App → Features → In-App Purchases
- [ ] Verify you have created a product with ID: `com.blinklabs.catgpt.remove_ads`
- [ ] Product Type should be: **Non-Consumable**
- [ ] Product Status should be: **Ready to Submit** or **Approved**
- [ ] The product must be associated with your app version in TestFlight

### 3. Product ID Exact Match ⚠️ CRITICAL
- [ ] In App Store Connect, the Product ID must be **exactly**: `com.blinklabs.catgpt.remove_ads`
- [ ] Check for any typos, extra spaces, or case differences
- [ ] This must match exactly what's in `lib/constants/purchase_constants.dart`:
  ```dart
  const String noAdsProductId = 'com.blinklabs.catgpt.remove_ads';
  ```

### 4. App Version Association ✅
- [ ] In App Store Connect → TestFlight → Your Build
- [ ] Ensure the in-app purchase product is associated with the build version you're testing
- [ ] The product must be in "Ready to Submit" status (or "Approved") before it appears in TestFlight

### 5. Sandbox Test Account Setup ✅
- [ ] Go to App Store Connect → Users and Access → Sandbox Testers
- [ ] Create a sandbox test account (use a different email than your Apple ID)
- [ ] Sign out of your regular Apple ID on the test device
- [ ] When prompted during purchase, sign in with the sandbox test account
- [ ] **Important**: TestFlight builds automatically use sandbox environment

### 6. Provisioning Profile & Signing ✅
- [ ] Open your project in Xcode
- [ ] Go to Signing & Capabilities tab
- [ ] Verify the Bundle Identifier is: `com.blinklabs.catgpt`
- [ ] Ensure "Automatically manage signing" is enabled OR you have a valid provisioning profile
- [ ] The provisioning profile must include In-App Purchase capability

### 7. Capabilities Check ✅
- [ ] In Xcode → Signing & Capabilities
- [ ] Verify "In-App Purchase" capability is added (should be automatic with Flutter)
- [ ] If missing, click "+ Capability" and add "In-App Purchase"

## Common Issues & Solutions

### Issue: "Store not available" or `isAvailable()` returns false
**Solution**: 
- Check internet connection
- Verify you're signed in with a sandbox account (not your regular Apple ID)
- Ensure the app is properly signed

### Issue: Product not found or `queryProductDetails` returns empty
**Solution**:
- Verify Product ID matches exactly (case-sensitive)
- Ensure product is in "Ready to Submit" or "Approved" status in App Store Connect
- Wait 24-48 hours after creating the product for it to propagate
- Ensure product is associated with your TestFlight build

### Issue: Purchase fails silently
**Solution**:
- Check that you're using a sandbox test account
- Verify the product is approved and associated with your build
- Check Xcode console for detailed error messages
- Ensure you're testing on a physical device (TestFlight requires this)

### Issue: "This In-App Purchase has already been bought"
**Solution**:
- This is normal for non-consumable purchases
- Use "Restore Purchases" button to restore previous purchases
- Or sign out of sandbox account and sign back in

## Testing Steps

1. **Build & Upload**:
   - Build your app for TestFlight
   - Upload to App Store Connect
   - Wait for processing to complete

2. **Install via TestFlight**:
   - Install the TestFlight app on your device
   - Install your app build from TestFlight

3. **Test Purchase Flow**:
   - Open your app
   - Navigate to Settings → Remove Ads
   - Tap the purchase button
   - When prompted, sign in with your **sandbox test account** (not your regular Apple ID)
   - Complete the purchase

4. **Verify Purchase**:
   - Check that ads are removed
   - Test "Restore Purchases" functionality
   - Verify purchase persists after app restart

## Debugging Tips

Add this debug logging to see what's happening:

```dart
// In settings_page.dart, add more logging:
Future<void> _initStoreInfo() async {
  setState(() {
    _isLoadingProducts = true;
    _purchaseError = null;
  });

  final available = await _inAppPurchase.isAvailable();
  debugPrint('Store available: $available'); // Add this
  
  if (!mounted) return;
  setState(() {
    _isStoreAvailable = available;
  });
  if (!available) {
    debugPrint('Store not available - check connection and sandbox account'); // Add this
    setState(() => _isLoadingProducts = false);
    return;
  }

  debugPrint('Querying product: $noAdsProductId'); // Add this
  final response = await _inAppPurchase.queryProductDetails({noAdsProductId});
  debugPrint('Product query result: ${response.productDetails.length} products found'); // Add this
  debugPrint('Product query error: ${response.error?.message}'); // Add this
  
  if (!mounted) return;
  setState(() {
    _noAdsProduct = response.productDetails.isNotEmpty
        ? response.productDetails.first
        : null;
    _purchaseError = response.error?.message;
    _isLoadingProducts = false;
  });
}
```

## Most Common Problem

The #1 issue is usually: **Product ID mismatch** or **Product not associated with TestFlight build**.

Double-check:
1. Product ID in App Store Connect matches exactly: `com.blinklabs.catgpt.remove_ads`
2. Product is in "Ready to Submit" or "Approved" status
3. Product is associated with your TestFlight build version



