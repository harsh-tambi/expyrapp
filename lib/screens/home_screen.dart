import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/items_provider.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/app_logo.dart';
import '../theme/app_theme.dart';
import '../models/item.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import 'signin_screen.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_formatter.dart';
import 'edit_item_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storageService = LocalStorageService();
  final _authService = AuthService();
  String _selectedFilter = 'all';
  String _searchTerm = '';
  String _selectedLocation = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value.toLowerCase();
    });
  }

  bool _itemMatchesSearch(Item item) {
    if (_searchTerm.isEmpty) return true;

    return item.name.toLowerCase().contains(_searchTerm) ||
        item.location.toLowerCase().contains(_searchTerm) ||
        item.expiryDate.toLowerCase().contains(_searchTerm);
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            _buildItemList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.white,
      child: Column(
        children: [
          Row(
            children: [
              const AppLogo(
                size: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    boxShadow: const [AppTheme.buttonShadow],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadius),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _signOut,
                tooltip: 'Sign Out',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Account for horizontal padding
    final spacing = 8.0;
    final chipWidth =
        (availableWidth - (spacing * 3)) / 4; // Equal width for all chips

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFilterChip('All', 'all', chipWidth),
          SizedBox(width: spacing),
          _buildFilterChip('Fridge', 'fridge', chipWidth),
          SizedBox(width: spacing),
          _buildFilterChip('Freezer', 'freezer', chipWidth),
          SizedBox(width: spacing),
          _buildFilterChip('Pantry', 'pantry', chipWidth),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, double width) {
    final isSelected = _selectedLocation == value;

    return SizedBox(
      width: width,
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.darkGreen,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedLocation = selected ? value : 'all';
          });
        },
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryGreen,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey[300]!,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildItemList() {
    return Expanded(
      child: Consumer<ItemsProvider>(
        builder: (context, provider, child) {
          final items = provider.items.where((item) {
            // First apply location filter
            if (_selectedFilter != 'all' && item.location != _selectedFilter) {
              return false;
            }
            // Then apply search filter
            return _itemMatchesSearch(item);
          }).toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppTheme.gray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchTerm.isEmpty
                        ? 'No items found'
                        : 'No matching items found',
                    style: TextStyle(
                      color: AppTheme.gray.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchTerm.isEmpty
                        ? 'Add some items to get started'
                        : 'Try adjusting your search',
                    style: TextStyle(
                      color: AppTheme.gray.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    final daysUntilExpiry = _calculateDaysUntilExpiry(item.expiryDate);

    return Dismissible(
      key: Key(item.id),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete confirmation
          final bool? result = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text(
                  'Delete Item',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete ${item.name}?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.darkGreen),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          );
          return result ?? false;
        } else if (direction == DismissDirection.startToEnd) {
          // Edit action
          _editItem(item);
          return false; // Don't dismiss the item
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteItem(item);
        }
      },
      background: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Icon(
          Icons.edit,
          color: Colors.white,
          size: 24,
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Item Image
              if (item.imagePath != null) ...[
                Container(
                  width: 52,
                  height: 52,
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
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getLocationIcon(item.location),
                          size: 14,
                          color: AppTheme.darkGreen.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.location.substring(0, 1).toUpperCase() +
                              item.location.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkGreen.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 14,
                          color: _getExpiryColor(daysUntilExpiry),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryText(daysUntilExpiry),
                          style: TextStyle(
                            fontSize: 13,
                            color: _getExpiryColor(daysUntilExpiry),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatExpiryText(int days) {
    if (days < 0) {
      return 'Expired ${-days} ${days == -1 ? 'day' : 'days'} ago';
    } else if (days == 0) {
      return 'Expires today';
    } else {
      return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
    }
  }

  Color _getExpiryColor(int days) {
    if (days < 0) {
      return Colors.red[700]!;
    } else if (days <= 3) {
      return Colors.orange[700]!;
    } else if (days <= 7) {
      return Colors.amber[700]!;
    } else {
      return AppTheme.darkGreen;
    }
  }

  IconData _getLocationIcon(String location) {
    switch (location.toLowerCase()) {
      case 'fridge':
        return Icons.kitchen;
      case 'freezer':
        return Icons.ac_unit;
      case 'pantry':
        return Icons.shelves;
      default:
        return Icons.kitchen;
    }
  }

  int _calculateDaysUntilExpiry(String expiryDate) {
    final expiry = DateTime.parse(expiryDate);
    final now = DateTime.now();
    final difference = expiry.difference(now).inDays;
    return difference;
  }

  void _editItem(Item item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(
          itemId: item.id,
          name: item.name,
          expiryDate: item.expiryDate,
          location: item.location,
          imagePath: item.imagePath,
        ),
      ),
    );
  }

  void _deleteItem(Item item) {
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    itemsProvider.deleteItem(item.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} has been deleted'),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            itemsProvider.addItems([
              {
                'id': item.id,
                'name': item.name,
                'expiryDate': item.expiryDate,
                'location': item.location,
                'imagePath': item.imagePath,
              }
            ]);
          },
        ),
      ),
    );
  }
}
