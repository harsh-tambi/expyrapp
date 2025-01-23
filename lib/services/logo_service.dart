import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class LogoService {
  static final LogoService _instance = LogoService._internal();
  static const String _logoKey = 'app_logo';
  static const String _logoFileName = 'app_logo.png';
  static const int _maxLogoSize = 800; // Maximum width/height for the logo

  factory LogoService() {
    return _instance;
  }

  LogoService._internal();

  Future<void> saveLogo(Uint8List logoBytes) async {
    try {
      // Decode and resize the image if needed
      final image = img.decodeImage(logoBytes);
      if (image == null) throw Exception('Failed to decode logo image');

      final resizedImage = _resizeImage(image);
      final compressedBytes = img.encodePng(resizedImage);

      if (kIsWeb) {
        // For web, store as base64 in SharedPreferences
        final base64Logo = base64Encode(compressedBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_logoKey, base64Logo);
      } else {
        // For native platforms, save to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final logoFile = File('${appDir.path}/$_logoFileName');
        await logoFile.writeAsBytes(compressedBytes);
      }
    } catch (e) {
      throw Exception('Failed to save logo: $e');
    }
  }

  Future<Uint8List?> getLogo() async {
    try {
      if (kIsWeb) {
        // For web, retrieve from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final base64Logo = prefs.getString(_logoKey);
        if (base64Logo != null) {
          return base64Decode(base64Logo);
        }
      } else {
        // For native platforms, read from file
        final appDir = await getApplicationDocumentsDirectory();
        final logoFile = File('${appDir.path}/$_logoFileName');
        if (await logoFile.exists()) {
          return await logoFile.readAsBytes();
        }
      }
      return null;
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  img.Image _resizeImage(img.Image image) {
    final width = image.width;
    final height = image.height;

    if (width <= _maxLogoSize && height <= _maxLogoSize) {
      return image;
    }

    if (width > height) {
      final newWidth = _maxLogoSize;
      final newHeight = (height * _maxLogoSize / width).round();
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      final newHeight = _maxLogoSize;
      final newWidth = (width * _maxLogoSize / height).round();
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  Future<void> clearLogo() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_logoKey);
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final logoFile = File('${appDir.path}/$_logoFileName');
        if (await logoFile.exists()) {
          await logoFile.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to clear logo: $e');
    }
  }
}
