import 'package:flutter/material.dart';

class LocationFilters extends StatelessWidget {
  final String selectedLocation;
  final ValueChanged<String> onLocationChange;

  const LocationFilters({
    super.key,
    required this.selectedLocation,
    required this.onLocationChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = [
      {'value': 'all', 'label': 'All', 'icon': Icons.all_inbox},
      {'value': 'fridge', 'label': 'Fridge', 'icon': Icons.kitchen},
      {'value': 'freezer', 'label': 'Freezer', 'icon': Icons.ac_unit},
      {'value': 'pantry', 'label': 'Pantry', 'icon': Icons.shelves},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: locations.map((location) {
          final isSelected = selectedLocation == location['value'];
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    location['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location['label'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  onLocationChange(location['value'] as String);
                }
              },
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              checkmarkColor: theme.colorScheme.onPrimary,
              showCheckmark: false,
              elevation: 0,
              pressElevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
}
