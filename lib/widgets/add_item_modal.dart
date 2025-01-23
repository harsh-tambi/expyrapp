import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import '../providers/items_provider.dart';
import '../theme/app_theme.dart';
import '../services/local_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../utils/date_formatter.dart';

class ItemData {
  String name;
  String location;
  String expiryDate;
  String imagePath;
  String? error;
  bool isProcessed;
  bool isProcessing;
  bool hasValidationError;

  ItemData({
    this.name = '',
    this.location = 'pantry',
    String? expiryDate,
    required this.imagePath,
    this.error,
    this.isProcessed = false,
    this.isProcessing = false,
    this.hasValidationError = false,
  }) : this.expiryDate =
            expiryDate ?? DateTime.now().toIso8601String().split('T')[0];

  bool validate() {
    hasValidationError = name.isEmpty ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryDate) ||
        !['pantry', 'fridge', 'freezer'].contains(location.toLowerCase());
    return !hasValidationError;
  }

  Map<String, String> toMap() {
    return {
      'name': name.isEmpty ? 'Unnamed Item' : name,
      'location': location.isEmpty ? 'pantry' : location.toLowerCase(),
      'expiryDate': RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryDate)
          ? expiryDate
          : DateTime.now().toIso8601String().split('T')[0],
      'imagePath': imagePath,
    };
  }

  @override
  String toString() {
    return 'ItemData(name: $name, expiryDate: $expiryDate, location: $location, isProcessed: $isProcessed)';
  }
}

class BatchProcessor {
  final int maxConcurrentRequests;
  final int batchSize;
  final Duration retryDelay;
  final int maxRetries;
  static const int _compressionThreshold = 2 * 1024 * 1024; // 2MB

  BatchProcessor({
    this.maxConcurrentRequests = 3,
    this.batchSize = 5,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
  });

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      // Decode image
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) throw 'Failed to decode image';

      // Calculate target size based on original size
      final double compressionRatio = bytes.length / _compressionThreshold;
      int targetWidth = image.width;
      int targetHeight = image.height;

      if (compressionRatio > 1) {
        final scale = 1 / sqrt(compressionRatio);
        targetWidth = (image.width * scale).round();
        targetHeight = (image.height * scale).round();
      }

      // Resize image if needed
      final resized = targetWidth != image.width || targetHeight != image.height
          ? img.copyResize(
              image,
              width: targetWidth,
              height: targetHeight,
              interpolation: img.Interpolation.linear,
            )
          : image;

      // Encode as JPEG with quality based on size
      final quality = (90 / compressionRatio).clamp(60, 90).round();
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes; // Return original if compression fails
    }
  }

  Future<List<ProcessingResult>> processBatch(
    List<ProcessingTask> tasks,
    Function(double) onProgressUpdate,
  ) async {
    final results = <ProcessingResult>[];
    final completer = Completer<List<ProcessingResult>>();
    final queue = Queue<ProcessingTask>.from(tasks);
    var completedTasks = 0;
    var inProgress = 0;

    void processNext() async {
      if (queue.isEmpty && inProgress == 0) {
        completer.complete(results);
        return;
      }

      while (queue.isNotEmpty && inProgress < maxConcurrentRequests) {
        final task = queue.removeFirst();
        inProgress++;

        processTask(task).then((result) {
          results.add(result);
          completedTasks++;
          inProgress--;

          final progress = completedTasks / tasks.length;
          onProgressUpdate(progress);

          processNext();
        }).catchError((error) {
          debugPrint('Error processing task: $error');
          if (task.retryCount < maxRetries) {
            task.retryCount++;
            queue.addLast(task);
          } else {
            results.add(ProcessingResult(
              task: task,
              success: false,
              error: error.toString(),
            ));
            completedTasks++;
          }
          inProgress--;
          processNext();
        });
      }
    }

    processNext();
    return completer.future;
  }

  Future<ProcessingResult> processTask(ProcessingTask task) async {
    try {
      if (task.retryCount > 0) {
        await Future.delayed(retryDelay * task.retryCount);
      }

      final bytes = await task.getBytes();
      if (bytes == null) {
        throw 'Failed to read image bytes';
      }

      // Skip compression if image is already small enough
      final compressedBytes = bytes.length > _compressionThreshold
          ? await _compressImage(bytes)
          : bytes;

      final content = [
        Content.text(_buildPrompt()),
        Content.data('image/jpeg', compressedBytes),
      ];

      final response = await task.model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw 'No response from API';
      }

      final data = _parseResponse(responseText);
      return ProcessingResult(
        task: task,
        success: true,
        data: data,
      );
    } catch (e) {
      return ProcessingResult(
        task: task,
        success: false,
        error: e.toString(),
      );
    }
  }

  String _buildPrompt() {
    return '''
      You are an AI assistant that extracts product information from grocery item images.
      
      Extract ONLY these details from the image:
      1. Product name (exactly as shown on package)
      2. Expiry date (convert to YYYY-MM-DD format)
      3. Storage location (must be one of: pantry, fridge, freezer)
      
      IMPORTANT:
      - Respond with ONLY a JSON object
      - No other text or explanations
      - No markdown formatting
      - If you cannot read or find any field, set it to null
      - Follow this exact format:
      {"name": "Product Name", "expiryDate": "YYYY-MM-DD", "location": "fridge"}
      
      Example responses:
      {"name": "Organic Milk", "expiryDate": "2024-03-15", "location": "fridge"}
      {"name": null, "expiryDate": "2025-06-30", "location": "pantry"}
      {"name": "Ice Cream", "expiryDate": null, "location": "freezer"}
    ''';
  }

  Map<String, dynamic> _parseResponse(String response) {
    final cleanJson =
        response.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(cleanJson) as Map<String, dynamic>;
  }
}

class ProcessingTask {
  final String imagePath;
  final GenerativeModel model;
  final Future<Uint8List?> Function() getBytes;
  int retryCount;

  ProcessingTask({
    required this.imagePath,
    required this.model,
    required this.getBytes,
    this.retryCount = 0,
  });
}

class ProcessingResult {
  final ProcessingTask task;
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;

  ProcessingResult({
    required this.task,
    required this.success,
    this.data,
    this.error,
  });
}

class AddItemModal extends StatefulWidget {
  const AddItemModal({super.key});

  @override
  State<AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<AddItemModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<ItemData> _items = [];
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _expiryControllers = {};
  final _storageService = LocalStorageService();
  late AnimationController _loadingController;
  final ScrollController scrollController = ScrollController();

  final _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyD5D7z5Kzm3Xs7gp4-mwfKze_jpV5VgJlU',
  );

  final _locations = [
    {'value': 'fridge', 'label': 'Fridge', 'icon': Icons.kitchen},
    {'value': 'freezer', 'label': 'Freezer', 'icon': Icons.ac_unit},
    {'value': 'pantry', 'label': 'Pantry', 'icon': Icons.shelves},
  ];

  static const int _maxConcurrentRequests = 3;

  final _batchProcessor = BatchProcessor();

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    for (var controller in _nameControllers.values) {
      controller.dispose();
    }
    for (var controller in _expiryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(int index, ItemData item) {
    if (!_nameControllers.containsKey(index)) {
      _nameControllers[index] = TextEditingController(text: item.name);
    }
    if (!_expiryControllers.containsKey(index)) {
      _expiryControllers[index] = TextEditingController(
        text: DateFormatter.formatToDisplay(item.expiryDate),
      );
    }
  }

  void _updateItemField(int index, String field, String value) {
    if (index >= _items.length) return;

    setState(() {
      final item = _items[index];
      _items[index] = ItemData(
        name: field == 'name' ? value : item.name,
        expiryDate: field == 'expiryDate' ? value : item.expiryDate,
        location: field == 'location' ? value : item.location,
        imagePath: item.imagePath,
        isProcessed: item.isProcessed,
        isProcessing: item.isProcessing,
        error: item.error,
        hasValidationError: false,
      );
    });
    debugPrint('Updated $field for item $index to: $value');
    debugPrint('Current item state: ${_items[index]}');
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      debugPrint('Processing ${images.length} images...');

      // Create processing tasks for each image
      final tasks = images.map((image) {
        return ProcessingTask(
          imagePath: image.path,
          model: _model,
          getBytes: () => image.readAsBytes(),
        );
      }).toList();

      // Process images in batches
      final results = await _batchProcessor.processBatch(
        tasks,
        (progress) {
          // We no longer need to update progress percentage
        },
      );

      // Handle results
      for (final result in results) {
        if (result.success && result.data != null) {
          final data = result.data!;
          setState(() {
            _items.add(ItemData(
              name: data['name']?.toString() ?? '',
              expiryDate: data['expiryDate']?.toString() ??
                  DateTime.now().toIso8601String().split('T')[0],
              location:
                  (data['location']?.toString() ?? 'fridge').toLowerCase(),
              imagePath: result.task.imagePath,
              isProcessed: true,
            ));
            final index = _items.length - 1;
            _initializeControllers(index, _items[index]);
          });
        } else {
          setState(() {
            _items.add(ItemData(
              name: '',
              expiryDate: DateTime.now().toIso8601String().split('T')[0],
              location: 'fridge',
              imagePath: result.task.imagePath,
              isProcessed: true,
            ));
            final index = _items.length - 1;
            _initializeControllers(index, _items[index]);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image added. Please fill in the item details.'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processImage(String imagePath, int index) async {
    if (!mounted) return;

    setState(() {
      _items[index] = ItemData(
        name: _items[index].name,
        expiryDate: _items[index].expiryDate,
        location: _items[index].location,
        imagePath: imagePath,
        isProcessing: true,
      );
    });

    try {
      // Process image with API
      final response = await _processImageWithAPI(imagePath);
      final Map<String, dynamic> data = jsonDecode(response);

      String? name = data['name'];
      String? expiryDate = data['expiryDate'];
      String? location = data['location']?.toLowerCase();

      // Handle missing or invalid data
      if (mounted) {
        final updatedItem = ItemData(
          name: name ?? '',
          expiryDate:
              expiryDate ?? DateTime.now().toIso8601String().split('T')[0],
          location: location ?? 'fridge',
          imagePath: imagePath,
          isProcessed: true,
          isProcessing: false,
        );

        setState(() {
          _items[index] = updatedItem;
          _nameControllers[index]?.text = updatedItem.name;
          if (expiryDate != null) {
            _expiryControllers[index]?.text =
                DateFormatter.formatToDisplay(expiryDate);
          } else {
            _expiryControllers[index]?.text = '';
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        setState(() {
          _items[index] = ItemData(
            name: '',
            expiryDate: DateTime.now().toIso8601String().split('T')[0],
            location: 'fridge',
            imagePath: imagePath,
            isProcessed: true,
            isProcessing: false,
          );
        });
      }
    }
  }

  Future<String> _processImageWithAPI(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();

      const prompt = '''
        You are an AI assistant that extracts product information from grocery item images.
        
        Extract ONLY these details from the image:
        1. Product name (exactly as shown on package)
        2. Expiry date (convert to YYYY-MM-DD format)
        3. Storage location (must be one of: pantry, fridge, freezer)
        
        IMPORTANT:
        - Respond with ONLY a JSON object
        - No other text or explanations
        - No markdown formatting
        - If you cannot read or find any field, set it to null
        - Follow this exact format:
        {"name": "Product Name", "expiryDate": "YYYY-MM-DD", "location": "fridge"}
        
        Example responses:
        {"name": "Organic Milk", "expiryDate": "2024-03-15", "location": "fridge"}
        {"name": null, "expiryDate": "2025-06-30", "location": "pantry"}
        {"name": "Ice Cream", "expiryDate": null, "location": "freezer"}
      ''';

      final content = [
        Content.text(prompt),
        Content.data('image/jpeg', imageBytes),
      ];

      debugPrint('Sending request to Gemini API...');
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        return '{"name": null, "expiryDate": null, "location": null}';
      }

      // Clean and parse response
      final cleanJson =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      // Validate JSON format
      try {
        jsonDecode(cleanJson);
        return cleanJson;
      } catch (e) {
        debugPrint('Invalid JSON response: $e');
        return '{"name": null, "expiryDate": null, "location": null}';
      }
    } catch (e) {
      debugPrint('Error in image processing: $e');
      return '{"name": null, "expiryDate": null, "location": null}';
    }
  }

  Future<void> _showDatePicker(int index) async {
    if (index >= _items.length) return;

    final initialDate = _items[index].expiryDate.isNotEmpty
        ? DateTime.tryParse(_items[index].expiryDate) ?? DateTime.now()
        : DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryGreen,
                  onPrimary: Colors.white,
                  surface: AppTheme.white,
                  onSurface: Colors.black87,
                ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null && mounted) {
      final storageDate = DateFormatter.formatFromCalendar(pickedDate);
      final displayDate = DateFormatter.formatToDisplay(storageDate);

      setState(() {
        _items[index] = ItemData(
          name: _items[index].name,
          expiryDate: storageDate,
          location: _items[index].location,
          imagePath: _items[index].imagePath,
          isProcessed: _items[index].isProcessed,
          isProcessing: _items[index].isProcessing,
        );
        _expiryControllers[index]?.text = displayDate;
      });
    }
  }

  bool _validateItems() {
    bool hasEmptyFields = false;
    List<String> emptyFields = [];

    for (var i = 0; i < _items.length; i++) {
      final name = _nameControllers[i]?.text ?? '';
      final expiryDate = _expiryControllers[i]?.text ?? '';

      if (name.isEmpty) {
        hasEmptyFields = true;
        emptyFields.add('name');
      }

      if (expiryDate.isEmpty) {
        hasEmptyFields = true;
        emptyFields.add('expiry date');
      }
    }

    if (hasEmptyFields) {
      final fieldText = emptyFields.toSet().join(' and ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in the $fieldText for all items'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveAllItems() async {
    if (_items.isEmpty) return;

    // Log current state for debugging
    debugPrint('\nValidating items before save:');
    for (var item in _items) {
      debugPrint(
          'Item: name="${item.name}", expiryDate="${item.expiryDate}", location="${item.location}"');
    }

    if (!_validateItems()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      final itemsToSave = _items.map((item) {
        // Ensure all fields have valid values
        return {
          'name': item.name.isNotEmpty ? item.name : 'Unnamed Item',
          'expiryDate': RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item.expiryDate)
              ? item.expiryDate
              : DateTime.now().toIso8601String().split('T')[0],
          'location': ['pantry', 'fridge', 'freezer']
                  .contains(item.location.toLowerCase())
              ? item.location.toLowerCase()
              : 'pantry',
          'imagePath': item.imagePath,
        };
      }).toList();

      debugPrint('\nSaving items:');
      for (var item in itemsToSave) {
        debugPrint('Item to save: $item');
      }

      await itemsProvider.addItems(itemsToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All items saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving items: ${e.toString()}'),
            backgroundColor: const Color(0xFFF8D7DA),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildImageContainer(ItemData item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: kIsWeb
            ? FutureBuilder<String?>(
                future: _getWebImageUrl(item.imagePath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    debugPrint('Error loading image: ${snapshot.error}');
                    return const Icon(Icons.error_outline, color: Colors.red);
                  }
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error displaying image: $error');
                      return const Icon(Icons.error_outline, color: Colors.red);
                    },
                  );
                },
              )
            : FutureBuilder<Uint8List?>(
                future: _storageService.getImage(item.imagePath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    debugPrint('Error loading image: ${snapshot.error}');
                    return const Icon(Icons.error_outline, color: Colors.red);
                  }
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error displaying image: $error');
                      return const Icon(Icons.error_outline, color: Colors.red);
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<String?> _getWebImageUrl(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    bool isDateField = false,
    int index = 0,
  }) {
    final item = _items[index];
    final hasError = item.hasValidationError;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        errorText: hasError ? '$label is required' : null,
        suffixIcon: isDateField
            ? IconButton(
                icon: const Icon(Icons.calendar_today, size: 20),
                onPressed: () => _showDatePicker(index),
              )
            : null,
      ),
      readOnly: isDateField,
      onTap: isDateField ? () => _showDatePicker(index) : null,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.viewPadding.top;
    final bottomPadding = mediaQuery.viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar for dragging
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.darkGreen,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 16),
                      _buildItemList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.neutralWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _loadingController,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGreen,
                            width: 3,
                            strokeAlign: BorderSide.strokeAlignCenter,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing images...',
                      style: TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to add photo',
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildItemCard(ItemData item, int index) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[300]!),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
    );

    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.darkGreen.withOpacity(0.8),
      fontFamily: 'Roboto',
    );

    final inputStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppTheme.darkGreen,
      fontFamily: 'Roboto',
    );

    final errorStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: Colors.red[700]?.withOpacity(0.9),
      fontFamily: 'Roboto',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.imagePath != null) ...[
              Container(
                height: 100, // Reduced height
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.imagePath!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12), // Reduced spacing
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameControllers[index],
                        style: inputStyle,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          labelStyle: labelStyle,
                          hintText: 'Enter item name',
                          errorText: item.isProcessed &&
                                  _nameControllers[index]?.text.isEmpty == true
                              ? 'Required'
                              : null,
                          errorStyle: errorStyle,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: AppTheme.neutralWhite,
                          border: inputBorder,
                          focusedBorder: focusedBorder,
                          enabledBorder: inputBorder,
                        ),
                        onChanged: (value) =>
                            _updateItemField(index, 'name', value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12), // Reduced spacing
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _showDatePicker(index),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _expiryControllers[index],
                        textAlign: TextAlign.center,
                        style: inputStyle,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          labelStyle: labelStyle,
                          hintText: 'Select date',
                          errorText: item.isProcessed &&
                                  _expiryControllers[index]?.text.isEmpty ==
                                      true
                              ? 'Required'
                              : null,
                          errorStyle: errorStyle,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: AppTheme.neutralWhite,
                          border: inputBorder,
                          focusedBorder: focusedBorder,
                          enabledBorder: inputBorder,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.darkGreen.withOpacity(0.8),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: item.location,
              style: inputStyle,
              decoration: InputDecoration(
                labelText: 'Storage Location',
                labelStyle: labelStyle,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                filled: true,
                fillColor: AppTheme.neutralWhite,
                border: inputBorder,
                focusedBorder: focusedBorder,
                enabledBorder: inputBorder,
              ),
              items: const [
                DropdownMenuItem(value: 'fridge', child: Text('Fridge')),
                DropdownMenuItem(value: 'freezer', child: Text('Freezer')),
                DropdownMenuItem(value: 'pantry', child: Text('Pantry')),
              ],
              onChanged: (value) =>
                  _updateItemField(index, 'location', value ?? 'fridge'),
            ),
            if (item.isProcessed &&
                (_nameControllers[index]?.text.isEmpty == true ||
                    _expiryControllers[index]?.text.isEmpty == true)) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Please fill in all required fields before saving.',
                  style: TextStyle(
                    color: Colors.red[700]?.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Roboto',
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemList() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) => _buildItemCard(_items[index], index),
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickImages,
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: AppTheme.darkGreen,
                  ),
                  label: Text(
                    'Add More Images',
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed:
                      _isLoading || _items.isEmpty ? null : _saveAllItems,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shadowColor: AppTheme.primaryGreen.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLoading ? 'Saving...' : 'Save All Items',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
