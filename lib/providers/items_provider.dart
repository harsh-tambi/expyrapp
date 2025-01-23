import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../services/local_storage_service.dart';

class ItemsProvider with ChangeNotifier {
  List<Item> _items = [];
  final _uuid = const Uuid();
  final _storageService = LocalStorageService();
  static const int _chunkSize = 5; // Store 5 items per chunk

  List<Item> get items => [..._items];

  List<Item> get expiredItems => _items
      .where((item) => DateTime.parse(item.expiryDate).isBefore(DateTime.now()))
      .toList();

  List<Item> get itemsExpiringThisWeek {
    final now = DateTime.now();
    final oneWeekFromNow = now.add(const Duration(days: 7));
    return _items.where((item) {
      final expiryDate = DateTime.parse(item.expiryDate);
      return expiryDate.isAfter(now) && expiryDate.isBefore(oneWeekFromNow);
    }).toList();
  }

  List<Item> get itemsExpiringNextWeek {
    final oneWeekFromNow = DateTime.now().add(const Duration(days: 7));
    final twoWeeksFromNow = DateTime.now().add(const Duration(days: 14));
    return _items.where((item) {
      final expiryDate = DateTime.parse(item.expiryDate);
      return expiryDate.isAfter(oneWeekFromNow) &&
          expiryDate.isBefore(twoWeeksFromNow);
    }).toList();
  }

  List<Item> get itemsExpiringLater {
    final twoWeeksFromNow = DateTime.now().add(const Duration(days: 14));
    return _items
        .where(
            (item) => DateTime.parse(item.expiryDate).isAfter(twoWeeksFromNow))
        .toList();
  }

  Future<void> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final numChunks = prefs.getInt('items_chunk_count') ?? 0;

    _items.clear();

    // Load each chunk
    for (int i = 0; i < numChunks; i++) {
      final chunkJson = prefs.getString('items_chunk_$i');
      if (chunkJson != null) {
        try {
          final chunkList = jsonDecode(chunkJson) as List;
          _items.addAll(chunkList.map((item) => Item.fromJson(item)));
        } catch (e) {
          debugPrint('Error loading chunk $i: $e');
          // If a chunk is corrupted, we'll skip it
          continue;
        }
      }
    }

    // Sort items by expiry date
    _items.sort((a, b) =>
        DateTime.parse(a.expiryDate).compareTo(DateTime.parse(b.expiryDate)));
    notifyListeners();
  }

  Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();

    // First clear all existing chunks
    final oldNumChunks = prefs.getInt('items_chunk_count') ?? 0;
    for (int i = 0; i < oldNumChunks; i++) {
      await prefs.remove('items_chunk_$i');
    }

    // Sort items by expiry date before saving
    _items.sort((a, b) =>
        DateTime.parse(a.expiryDate).compareTo(DateTime.parse(b.expiryDate)));

    // Split items into chunks and save
    final numChunks = (_items.length / _chunkSize).ceil();
    for (int i = 0; i < numChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize < _items.length)
          ? start + _chunkSize
          : _items.length;
      final chunk = _items.sublist(start, end);
      final chunkJson = jsonEncode(chunk.map((item) => item.toJson()).toList());
      await prefs.setString('items_chunk_$i', chunkJson);
    }

    // Save the number of chunks
    await prefs.setInt('items_chunk_count', numChunks);
  }

  Future<void> addItems(List<Map<String, dynamic>> items) async {
    final newItems = items.map((item) => Item(
          id: _uuid.v4(),
          name: item['name'] as String,
          location: item['location'] as String,
          expiryDate: item['expiryDate'] as String,
          imagePath: item['imagePath'] as String?,
          addedDate: DateTime.now().toIso8601String(),
        ));

    _items.addAll(newItems);
    notifyListeners();
    await saveItems();
  }

  Future<void> addItem({
    required String name,
    required String location,
    required String expiryDate,
    String? imagePath,
  }) async {
    final item = Item(
      id: _uuid.v4(),
      name: name,
      location: location,
      expiryDate: expiryDate,
      imagePath: imagePath,
      addedDate: DateTime.now().toIso8601String(),
    );

    _items.add(item);
    notifyListeners();
    await saveItems();
  }

  Future<void> deleteItem(String id) async {
    final item = _items.firstWhere((item) => item.id == id);
    if (item.imagePath != null) {
      await _storageService.deleteImage(item.imagePath!);
    }
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await saveItems();
  }

  Future<void> deleteItems(List<String> ids) async {
    for (final id in ids) {
      final item = _items.firstWhere((item) => item.id == id);
      if (item.imagePath != null) {
        await _storageService.deleteImage(item.imagePath!);
      }
    }
    _items.removeWhere((item) => ids.contains(item.id));
    notifyListeners();
    await saveItems();
  }

  List<Item> filterItems({
    required String searchTerm,
    required String selectedLocation,
  }) {
    return _items.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(searchTerm.toLowerCase());
      final matchesLocation =
          selectedLocation == 'all' || item.location == selectedLocation;
      return matchesSearch && matchesLocation;
    }).toList();
  }

  Future<void> clearExpiredItems() async {
    final now = DateTime.now();
    final expiredItems = _items
        .where((item) => DateTime.parse(item.expiryDate).isBefore(now))
        .toList();
    for (final item in expiredItems) {
      if (item.imagePath != null) {
        await _storageService.deleteImage(item.imagePath!);
      }
    }
    _items.removeWhere((item) => DateTime.parse(item.expiryDate).isBefore(now));
    notifyListeners();
    await saveItems();
  }

  Future<void> updateItem(
    String id,
    String name,
    String expiryDate,
    String location,
  ) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final updatedItem = Item(
      id: id,
      name: name,
      expiryDate: expiryDate,
      location: location,
      imagePath: _items[index].imagePath,
      addedDate: _items[index].addedDate,
    );

    _items[index] = updatedItem;
    notifyListeners();

    // Update in local storage
    await _storageService.updateItem(updatedItem);
  }
}
