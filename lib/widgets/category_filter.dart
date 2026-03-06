import 'package:flutter/material.dart';
import '../models/alarm_item.dart';

class CategoryFilter extends StatelessWidget {
  final AlarmCategory? selectedCategory;
  final Function(AlarmCategory?) onCategoryChanged;

  const CategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 전체
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selectedCategory == null,
              onSelected: (_) => onCategoryChanged(null),
              avatar: selectedCategory == null
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    )
                  : null,
            ),
          ),

          // 각 카테고리
          ...AlarmCategory.values.map((category) {
            final alarm = AlarmItem(
              id: '',
              time: DateTime.now(),
              content: '',
              isActive: false,
              category: category,
            );

            final isSelected = selectedCategory == category;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: alarm.categoryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(alarm.categoryLabel),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => onCategoryChanged(category),
                backgroundColor: alarm.categoryColor.withOpacity(0.1),
                selectedColor: alarm.categoryColor.withOpacity(0.3),
              ),
            );
          }),
        ],
      ),
    );
  }
}
