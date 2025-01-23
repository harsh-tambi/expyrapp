import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/items_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  final String name;
  final String expiryDate;
  final String location;
  final String? imagePath;

  const EditItemScreen({
    super.key,
    required this.itemId,
    required this.name,
    required this.expiryDate,
    required this.location,
    this.imagePath,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _expiryController;
  late String _selectedLocation;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _expiryController = TextEditingController(
      text: DateFormatter.formatToDisplay(widget.expiryDate),
    );
    _selectedLocation = widget.location;

    // Listen for changes to update the _hasChanges flag
    _nameController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      _hasChanges = _nameController.text != widget.name ||
          _selectedLocation != widget.location ||
          _expiryController.text !=
              DateFormatter.formatToDisplay(widget.expiryDate);
    });
  }

  Future<void> _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(widget.expiryDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.darkGreen,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final storageDate = DateFormatter.formatFromCalendar(pickedDate);
      final displayDate = DateFormatter.formatToDisplay(storageDate);
      setState(() {
        _expiryController.text = displayDate;
        _onFieldChanged();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);

    // Convert display date back to storage format
    final storageDate = DateFormatter.formatToStorage(
      DateFormatter.parseDisplayDate(_expiryController.text),
    );

    // Update the item
    await itemsProvider.updateItem(
      widget.itemId,
      _nameController.text,
      storageDate,
      _selectedLocation,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item updated successfully'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.neutralWhite,
        appBar: AppBar(
          backgroundColor: AppTheme.neutralWhite,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.darkGreen),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Edit Item',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          actions: [
            if (_hasChanges)
              TextButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imagePath != null) ...[
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.8),
                    fontFamily: 'Roboto',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2_outlined,
                      color: AppTheme.darkGreen),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryController,
                readOnly: true,
                onTap: _showDatePicker,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  labelStyle: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.8),
                    fontFamily: 'Roboto',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today,
                      color: AppTheme.darkGreen),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Storage Location',
                  labelStyle: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.8),
                    fontFamily: 'Roboto',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  prefixIcon:
                      const Icon(Icons.kitchen, color: AppTheme.darkGreen),
                ),
                items: const [
                  DropdownMenuItem(value: 'pantry', child: Text('Pantry')),
                  DropdownMenuItem(value: 'fridge', child: Text('Fridge')),
                  DropdownMenuItem(value: 'freezer', child: Text('Freezer')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLocation = value;
                      _onFieldChanged();
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
