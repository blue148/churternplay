import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// One selectable sort option: a value of type [T] and its display [label].
class SortOption<T> {
  final T value;
  final String label;

  /// Optional section heading shown above the first option of each group.
  final String? group;
  const SortOption(this.value, this.label, {this.group});
}

/// Shows a single-select, instant-apply sort bottom sheet. Returns the chosen
/// value, or null if dismissed without a selection.
Future<T?> showSortBottomSheet<T>({
  required BuildContext context,
  required List<SortOption<T>> options,
  required T current,
  String title = 'Sort by',
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.parchment50,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(title,
                style: AppTextStyles.display(size: 22, weight: FontWeight.w400)
                    .copyWith(color: AppColors.ink500)),
          ),
          for (var i = 0; i < options.length; i++) ...[
            if (options[i].group != null &&
                (i == 0 || options[i - 1].group != options[i].group))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(options[i].group!.toUpperCase(),
                      style: AppTextStyles.label()),
                ),
              ),
            _optionTile(sheetContext, options[i], current),
          ],
          const SizedBox(height: 8),
        ],
      ),
      ),
    ),
  );
}

Widget _optionTile<T>(
    BuildContext sheetContext, SortOption<T> option, T current) {
  return ListTile(
    dense: true,
    title: Text(
      option.label,
      style: AppTextStyles.body(
        size: 14,
        color: AppColors.ink500,
        weight: option.value == current ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
    trailing: option.value == current
        ? const Icon(Icons.check, size: 18, color: AppColors.clay400)
        : null,
    onTap: () => Navigator.pop(sheetContext, option.value),
  );
}
