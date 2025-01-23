import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/items_provider.dart';
import 'package:intl/intl.dart';

class ItemsList extends StatelessWidget {
  final String searchTerm;
  final String selectedLocation;

  const ItemsList({
    super.key,
    required this.searchTerm,
    required this.selectedLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsProvider = Provider.of<ItemsProvider>(context);
    final filteredItems = itemsProvider.filterItems(
      searchTerm: searchTerm,
      selectedLocation: selectedLocation,
    );

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          context,
          'Expired',
          itemsProvider.expiredItems,
          Colors.red,
        ),
        _buildSection(
          context,
          'Expiring This Week',
          itemsProvider.itemsExpiringThisWeek,
          Colors.orange,
        ),
        _buildSection(
          context,
          'Expiring Next Week',
          itemsProvider.itemsExpiringNextWeek,
          Colors.blue,
        ),
        _buildSection(
          context,
          'Expiring Later',
          itemsProvider.itemsExpiringLater,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<dynamic> items,
    Color color,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _buildItemCard(context, item, color)).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, dynamic item, Color color) {
    final theme = Theme.of(context);
    final expiryDate = DateTime.parse(item.expiryDate);
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Implement edit item
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (item.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.image_not_supported,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getLocationIcon(item.location),
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.location[0].toUpperCase() +
                              item.location.substring(1),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryText(daysUntilExpiry),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                onPressed: () {
                  Provider.of<ItemsProvider>(context, listen: false)
                      .deleteItem(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
        return Icons.all_inbox;
    }
  }

  String _formatExpiryText(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) {
      return 'Expired ${-daysUntilExpiry}d ago';
    } else if (daysUntilExpiry == 0) {
      return 'Expires today';
    } else {
      return 'Expires in ${daysUntilExpiry}d';
    }
  }
}
