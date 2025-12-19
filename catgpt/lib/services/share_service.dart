import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Creates an Instagram-like image with the original image and text overlay
  /// Returns the path to the generated image file, or null on error
  static Future<String?> createInstagramStyleImage({
    required Uint8List imageBytes,
    required String text,
    required BuildContext context,
    int imageWidth = 1080,
  }) async {
    try {
      // Decode the original image
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Extract main text (remove reasoning brackets)
      final mainText = _extractMainText(text);

      // Get original image dimensions
      final originalWidth = originalImage.width.toDouble();
      final originalHeight = originalImage.height.toDouble();
      final aspectRatio = originalWidth / originalHeight;

      // Calculate scaling factor based on image size
      // Use the image width as base, but ensure minimum sizes for readability
      final baseScale = imageWidth / 1080.0; // Scale relative to 1080px standard
      final minScale = 0.5; // Minimum scale for very small images
      final maxScale = 2.0; // Maximum scale for very large images
      final scale = baseScale.clamp(minScale, maxScale);

      // Calculate font sizes based on scale
      final textFontSize = (34 * scale).round().clamp(20, 60).toDouble();

      // Calculate spacing and padding based on scale
      final horizontalPadding = (60 * scale).round();
      final boxPadding = (50 * scale).round().toDouble();
      final watermarkHeight = (50 * scale).round().toDouble();

      // Calculate text box height - use text painter to measure
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: textFontSize,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      final textSpan = TextSpan(text: mainText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 8, // Allow more lines for smaller images
      );
      textPainter.layout(maxWidth: imageWidth - (horizontalPadding * 2));
      final textHeight = textPainter.height;
      
      // Box height: text height + padding top/bottom + watermark space
      final boxHeight = (textHeight + (boxPadding * 2) + watermarkHeight).round();

      // Image should be 2/3 bigger than the box, so: image height = box height * (1 + 2/3) = box height * 5/3
      final targetImageHeight = (boxHeight * 5 / 3).round();

      // Resize image to fit the target height, maintaining aspect ratio
      int finalHeight = targetImageHeight;
      int finalWidth = (finalHeight * aspectRatio).round();
      
      // If width exceeds max width, scale down proportionally
      if (finalWidth > imageWidth) {
        finalWidth = imageWidth;
        finalHeight = (finalWidth / aspectRatio).round();
      }

      // Ensure minimum dimensions for very small images
      if (finalWidth < 300 || finalHeight < 200) {
        if (finalWidth < 300) {
          finalWidth = 300;
          finalHeight = (finalWidth / aspectRatio).round();
        }
        if (finalHeight < 200) {
          finalHeight = 200;
          finalWidth = (finalHeight * aspectRatio).round();
        }
        // Recalculate box based on adjusted image size
        final adjustedScale = finalWidth / 1080.0;
        final adjustedTextSize = (34 * adjustedScale).round().clamp(20, 60).toDouble();
        final adjustedTextStyle = TextStyle(
          color: Colors.white,
          fontSize: adjustedTextSize,
          fontWeight: FontWeight.w600,
          height: 1.4,
        );
        final adjustedTextSpan = TextSpan(text: mainText, style: adjustedTextStyle);
        final adjustedTextPainter = TextPainter(
          text: adjustedTextSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 8,
        );
        adjustedTextPainter.layout(maxWidth: finalWidth - (horizontalPadding * 2));
        final adjustedTextHeight = adjustedTextPainter.height;
        final adjustedBoxHeight = (adjustedTextHeight + (boxPadding * 2) + watermarkHeight).round();
        // Update boxHeight and recalculate final dimensions
        final newTargetHeight = (adjustedBoxHeight * 5 / 3).round();
        if (newTargetHeight > finalHeight) {
          finalHeight = newTargetHeight;
          finalWidth = (finalHeight * aspectRatio).round();
          if (finalWidth > imageWidth) {
            finalWidth = imageWidth;
            finalHeight = (finalWidth / aspectRatio).round();
          }
        }
      }

      // Resize image
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: finalWidth,
        height: finalHeight,
        interpolation: img.Interpolation.cubic,
      );

      // Total image height will be calculated after final dimensions are determined

      // Convert image to ui.Image
      final uiImage = await _imgImageToUiImage(resizedImage);
      if (uiImage == null) {
        debugPrint('Failed to convert image to ui.Image');
        return null;
      }

      // Recalculate final scale based on actual finalWidth for consistent sizing
      final finalScale = (finalWidth / 1080.0).clamp(minScale, maxScale);
      final finalTextFontSize = (34 * finalScale).round().clamp(20, 60).toDouble();
      final finalWatermarkFontSize = (18 * finalScale).round().clamp(12, 32).toDouble();
      // Make logo bigger - increase base size from 32 to 48
      final finalLogoSize = (48 * finalScale).round().clamp(36, 72);
      final finalHorizontalPadding = (60 * finalScale).round();
      final finalBoxPadding = (50 * finalScale).round().toDouble();
      final finalWatermarkHeight = (50 * finalScale).round().toDouble();
      
      // Ensure watermark has enough space - adjust watermarkHeight if needed
      final minWatermarkHeight = finalLogoSize + 10; // Logo + padding
      final adjustedWatermarkHeight = finalWatermarkHeight > minWatermarkHeight 
          ? finalWatermarkHeight 
          : minWatermarkHeight.toDouble();

      // Recalculate box with final dimensions
      final finalTextStyle = TextStyle(
        color: Colors.white,
        fontSize: finalTextFontSize,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      final finalTextSpan = TextSpan(text: mainText, style: finalTextStyle);
      final finalTextPainter = TextPainter(
        text: finalTextSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 8,
      );
      finalTextPainter.layout(maxWidth: finalWidth - (finalHorizontalPadding * 2));
      final finalTextHeight = finalTextPainter.height;
      final finalBoxHeight = (finalTextHeight + (finalBoxPadding * 2) + adjustedWatermarkHeight).round();
      
      // Adjust total height if box height changed
      final adjustedTotalHeight = finalHeight + finalBoxHeight;

      // Create a picture recorder for the final image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, finalWidth.toDouble(), adjustedTotalHeight.toDouble()));

      // Draw the main image at the top
      final paint = Paint();
      canvas.drawImage(uiImage, Offset.zero, paint);
      uiImage.dispose();

      // Draw dark themed box below the image
      final boxY = finalHeight.toDouble();
      final boxRect = Rect.fromLTWH(0, boxY, finalWidth.toDouble(), finalBoxHeight.toDouble());
      
      // Dark gradient background for the box
      final boxGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A1A1A), // Dark gray
          Color(0xFF0F0F0F), // Darker gray
        ],
      );
      final boxPaint = Paint()
        ..shader = boxGradient.createShader(boxRect);
      canvas.drawRect(boxRect, boxPaint);

      // Draw subtle border at top of box
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, boxY),
        Offset(finalWidth.toDouble(), boxY),
        borderPaint,
      );

      // Draw translated text in the box
      finalTextPainter.layout(maxWidth: finalWidth - (finalHorizontalPadding * 2));
      final textOffset = Offset(
        finalHorizontalPadding.toDouble(),
        boxY + finalBoxPadding,
      );
      finalTextPainter.paint(canvas, textOffset);

      // Load logo asset for watermark
      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load('assets/icons/catgpt_logo.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Could not load logo: $e');
      }

      // Decode and resize logo for watermark
      img.Image? logoImage;
      if (logoBytes != null) {
        logoImage = img.decodeImage(logoBytes);
        if (logoImage != null) {
          logoImage = img.copyResize(logoImage, width: finalLogoSize, height: finalLogoSize);
          
          // Recolor logo: set all non-transparent pixels to white, preserve alpha
          for (int y = 0; y < logoImage.height; y++) {
            for (int x = 0; x < logoImage.width; x++) {
              final pixel = logoImage.getPixel(x, y);
              // If the pixel is not fully transparent (alpha > 0)
              if (pixel.a > 0) {
                logoImage.setPixel(x, y, img.ColorRgba8(255, 255, 255, pixel.a.toInt()));
              }
            }
          }
        }
      }

      // Draw watermark in bottom left of the box
      // Ensure logo is not cropped - position it with adequate padding
      final logoPadding = (40 * finalScale).round();
      final watermarkY = boxY + finalBoxHeight - adjustedWatermarkHeight + (adjustedWatermarkHeight - finalLogoSize) / 2;
      
      if (logoImage != null) {
        final logoUiImage = await _imgImageToUiImage(logoImage);
        if (logoUiImage != null) {
          // Ensure logo is positioned within bounds and not cropped
          final logoX = logoPadding.toDouble();
          final logoY = watermarkY;
          
          // Verify logo fits within image bounds
          if (logoX + finalLogoSize <= finalWidth && logoY + finalLogoSize <= adjustedTotalHeight) {
            canvas.drawImage(logoUiImage, Offset(logoX, logoY), paint);
          }
          logoUiImage.dispose();
        }
      }

      // Draw watermark text next to logo
      final watermarkStyle = TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontSize: finalWatermarkFontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      );
      final watermarkSpan = TextSpan(text: 'Translated with CatGPT', style: watermarkStyle);
      final watermarkPainter = TextPainter(
        text: watermarkSpan,
        textDirection: TextDirection.ltr,
      );
      watermarkPainter.layout();
      
      // Position text next to logo, vertically centered with logo
      final textSpacing = (10 * finalScale).round();
      final textX = logoPadding + finalLogoSize + textSpacing;
      // Ensure text fits within image bounds
      if (textX + watermarkPainter.width <= finalWidth) {
        final textY = watermarkY + (finalLogoSize - watermarkPainter.height) / 2;
        final watermarkOffset = Offset(textX.toDouble(), textY);
        watermarkPainter.paint(canvas, watermarkOffset);
      }

      // Convert picture to image
      final picture = recorder.endRecording();
      final finalUiImage = await picture.toImage(finalWidth, adjustedTotalHeight);
      picture.dispose();

      // Convert ui.Image to bytes
      final byteData = await finalUiImage.toByteData(format: ui.ImageByteFormat.png);
      finalUiImage.dispose();

      if (byteData == null) {
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/catgpt_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error creating Instagram-style image: $e');
      return null;
    }
  }

  /// Converts img.Image to ui.Image
  static Future<ui.Image?> _imgImageToUiImage(img.Image image) async {
    try {
      // Get RGBA bytes from the image
      final rgbaBytes = Uint8List(image.width * image.height * 4);
      int index = 0;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          rgbaBytes[index++] = pixel.r.toInt();
          rgbaBytes[index++] = pixel.g.toInt();
          rgbaBytes[index++] = pixel.b.toInt();
          rgbaBytes[index++] = pixel.a.toInt();
        }
      }
      
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgbaBytes,
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        (ui.Image decodedImage) {
          completer.complete(decodedImage);
        },
      );
      return completer.future;
    } catch (e) {
      debugPrint('Error converting img.Image to ui.Image: $e');
      return null;
    }
  }

  static String _extractMainText(String text) {
    final idx = text.indexOf('[');
    if (idx == -1) return text.trim();
    return text.substring(0, idx).trim();
  }

  /// Shares the image file using share_plus
  static Future<void> shareImage(
    String filePath, {
    String? subject,
    BuildContext? context,
  }) async {
    try {
      // On iOS, we need to provide sharePositionOrigin for the popover
      Rect? sharePositionOrigin;
      if (Platform.isIOS && context != null && context.mounted) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        // Position the share popover at the center-bottom of the screen
        // This is a safe default that works on both iPhone and iPad
        sharePositionOrigin = Rect.fromLTWH(
          screenSize.width / 2 - 50, // Center horizontally with 100px width
          screenSize.height - 100, // Near bottom of screen
          100, // Width
          50, // Height
        );
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? 'CatGPT Translation',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
      rethrow;
    }
  }

  /// Convenience method to create and share Instagram-style image
  static Future<void> shareInstagramStyle({
    required Uint8List imageBytes,
    required String text,
    required BuildContext context,
  }) async {
    try {
      final filePath = await createInstagramStyleImage(
        imageBytes: imageBytes,
        text: text,
        context: context,
      );

      if (filePath != null) {
        // Check if context is still mounted before using it
        await shareImage(
          filePath,
          context: context.mounted ? context : null,
        );
      } else {
        throw Exception('Failed to create shareable image');
      }
    } catch (e) {
      debugPrint('Error sharing Instagram-style image: $e');
      rethrow;
    }
  }
}
