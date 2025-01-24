import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import '../models/item.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  static const int _maxImageSize = 800; // Maximum width/height for images

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  /// Get current user's UID
  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Upload an item with an image and metadata to Firebase Storage and Firestore
  Future<void> uploadItem(Uint8List imageBytes, String itemName,
      String storageLocation, DateTime expiryDate) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception("User not authenticated");
      }

      final String fileName = '${_uuid.v4()}.png';

      // Decode and compress the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      final compressedImage = _resizeImage(image);
      final pngBytes = img.encodePng(compressedImage);

      // Upload the compressed image to Firebase Storage
      final imageRef = _storage.ref().child('users/$userId/images/$fileName');
      await imageRef.putData(Uint8List.fromList(pngBytes));

      // Get the image's download URL
      final imageUrl = await imageRef.getDownloadURL();

      // Add metadata to Firestore
      final item = {
        'itemName': itemName,
        'storageLocation': storageLocation,
        'expiryDate': expiryDate,
        'dateAdded': DateTime.now(),
        'imageUrl': imageUrl,
        'userId': userId,
      };

      await _firestore.collection('items').add(item);
    } catch (e) {
      throw Exception('Failed to upload item: $e');
    }
  }

  /// Retrieve items for the current user from Firestore
  Future<List<Map<String, dynamic>>> getItems() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception("User not authenticated");
      }

      final querySnapshot = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  /// Resize image to fit within the maximum allowed dimensions
  img.Image _resizeImage(img.Image image) {
    final width = image.width;
    final height = image.height;

    if (width <= _maxImageSize && height <= _maxImageSize) {
      return image;
    }

    if (width > height) {
      final newWidth = _maxImageSize;
      final newHeight = (height * _maxImageSize / width).round();
      return img.copyResize(image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear);
    } else {
      final newHeight = _maxImageSize;
      final newWidth = (width * _maxImageSize / height).round();
      return img.copyResize(image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear);
    }
  }

  /// Delete an item and its associated image from Firebase Storage and Firestore
  Future<void> deleteItem(String itemId, String imageUrl) async {
    try {
      // Delete the image from Firebase Storage
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      // Delete the metadata from Firestore
      await _firestore.collection('items').doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  /// Get a single image by its path
  Future<Uint8List?> getImage(String imagePath) async {
    try {
      final ref = _storage.refFromURL(imagePath);
      return await ref.getData();
    } catch (e) {
      throw Exception('Failed to fetch image: $e');
    }
  }

  /// Update an item in Firestore
  Future<void> updateItem(Item updatedItem) async {
    try {
      await _firestore.collection('items').doc(updatedItem.id).update(updatedItem.toJson());
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }
}
