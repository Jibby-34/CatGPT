# Google Play Billing Setup Guide

## Error: "This version of the application is not configured for billing through Google Play"

This error occurs when Google Play Billing cannot verify your app. Follow these steps to resolve it:

## Required Steps

### 1. Create App in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app or select your existing app
3. Complete the app setup (at minimum, you need to create a draft app listing)

### 2. Create In-App Product

1. In Google Play Console, go to **Monetize** → **Products** → **In-app products**
2. Click **Create product**
3. Set the following:
   - **Product ID**: `com.blinklabs.catgpt.remove_ads` (must match exactly)
   - **Name**: "Remove Ads" (or any display name)
   - **Description**: "Remove all ads and disable the 'Watch ad to translate' popup"
   - **Price**: $1.99 (or your desired price)
   - **Status**: Set to **Active**

### 3. Upload App to Internal Testing Track

**Important**: Google Play Billing requires the app to be uploaded to Google Play Console, even for testing.

1. Build a release APK or AAB:
   ```bash
   flutter build appbundle --release
   ```
   Or for APK:
   ```bash
   flutter build apk --release
   ```

2. In Google Play Console:
   - Go to **Testing** → **Internal testing**
   - Click **Create new release**
   - Upload your AAB/APK file
   - Add release notes
   - Save and review the release

3. **Important**: You don't need to publish to production, but the app must be uploaded to at least the internal testing track.

### 4. Add Testers (Optional but Recommended)

1. In **Internal testing** → **Testers**
2. Add your Google account email address
3. Create a testing link or add testers manually

### 5. Install App from Internal Testing

1. Use the internal testing link to install the app on your device
2. Or download directly from Google Play Console internal testing track
3. Make sure you're signed in with the same Google account used for testing

### 6. Test Purchase Flow

1. Open the app
2. Go to Settings → Remove Ads
3. Tap the Purchase button
4. Complete the purchase flow

## Alternative: Testing Without Upload (Limited)

If you need to test immediately without uploading to Google Play Console, you can:

1. **Use a signed release build** (not debug):
   ```bash
   flutter build apk --release
   ```
   Install this APK on your device.

2. **Note**: Even with a release build, Google Play Billing may still require the app to be in Google Play Console. The error you're seeing suggests this is the case.

## Troubleshooting

### Error persists after uploading to Google Play Console

1. **Wait 2-4 hours** after uploading - Google Play needs time to process
2. **Verify product ID matches exactly**: `com.blinklabs.catgpt.remove_ads`
3. **Check product status**: Must be "Active" in Google Play Console
4. **Ensure app version matches**: The version in your build must match what's uploaded
5. **Clear Google Play Store cache**: Settings → Apps → Google Play Store → Clear cache

### Product not found

- Verify product ID is exactly: `com.blinklabs.catgpt.remove_ads`
- Ensure product is in "Active" status
- Wait 24-48 hours after creating the product
- Check that the app is uploaded to Google Play Console

### Billing not available

- Ensure you're using a release build (not debug)
- Verify the app is uploaded to Google Play Console
- Check internet connection
- Make sure you're signed in with a Google account that has access to the app

## Quick Checklist

- [ ] App created in Google Play Console
- [ ] In-app product created with ID: `com.blinklabs.catgpt.remove_ads`
- [ ] Product status is "Active"
- [ ] App uploaded to Internal Testing track (at minimum)
- [ ] Using release build (not debug)
- [ ] Signed in with test account
- [ ] Waited 2-4 hours after upload for processing

## Testing in Debug Mode

Unfortunately, Google Play Billing typically doesn't work in debug mode. You need to:
1. Build a release version
2. Upload to Google Play Console
3. Install from internal testing track

This is a Google Play security requirement to prevent unauthorized billing.

