import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;
import '../models/item.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  final _uuid = const Uuid();
  static const String _imagePrefix = 'data:image/png;base64,';
  static const int _maxImageSize = 800; // Maximum width/height for images
  static const int _compressionThreshold = 5 * 1024 * 1024; // 5MB

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  Future<String> uploadImage(Uint8List imageBytes) async {
    try {
      final String fileName = '${_uuid.v4()}.png';

      // Decode and compress the image
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Resize if needed
      final compressedImage = _resizeImage(image);
      final pngBytes =
          img.encodePng(compressedImage, level: 6); // Higher compression

      if (kIsWeb) {
        // For web, store compressed image as base64
        final base64Image = _imagePrefix + base64Encode(pngBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(fileName, base64Image);
        return fileName;
      } else {
        // For native platforms, store compressed image in app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/item_images');

        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final String filePath = '${imagesDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
        return filePath;
      }
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  img.Image _resizeImage(img.Image image) {
    final width = image.width;
    final height = image.height;

    if (width <= _maxImageSize && height <= _maxImageSize) {
      return image;
    }

    if (width > height) {
      final newWidth = _maxImageSize;
      final newHeight = (height * _maxImageSize / width).round();
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      final newHeight = _maxImageSize;
      final newWidth = (width * _maxImageSize / height).round();
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  Future<void> deleteImage(String imagePathOrKey) async {
    try {
      if (kIsWeb) {
        // For web, remove from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(imagePathOrKey);
      } else {
        // For native platforms, delete the file
        final file = File(imagePathOrKey);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  Future<Uint8List?> getImage(String imagePathOrKey) async {
    try {
      if (kIsWeb) {
        // For web, get from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final base64Image = prefs.getString(imagePathOrKey);
        if (base64Image != null) {
          // Remove the data URL prefix if present
          final data = base64Image.startsWith(_imagePrefix)
              ? base64Image.substring(_imagePrefix.length)
              : base64Image;
          return base64Decode(data);
        }
        return null;
      } else {
        // For native platforms, read from file
        final file = File(imagePathOrKey);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      }
    } catch (e) {
      throw Exception('Failed to read image: $e');
    }
  }

  Future<List<Item>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('items');
    if (itemsJson == null) return [];

    final List<dynamic> decodedItems = jsonDecode(itemsJson);
    return decodedItems.map((item) => Item.fromJson(item)).toList();
  }

  Future<void> saveItems(List<Item> items) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = items.map((item) => item.toJson()).toList();
    await prefs.setString('items', jsonEncode(itemsJson));
  }

  Future<void> updateItem(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();

    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      items[index] = item;
      final itemsJson = items.map((item) => item.toJson()).toList();
      await prefs.setString('items', jsonEncode(itemsJson));
    }
  }

  Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();
    items.removeWhere((item) => item.id == id);
    final itemsJson = items.map((item) => item.toJson()).toList();
    await prefs.setString('items', jsonEncode(itemsJson));
  }

  Future<void> saveImage(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
