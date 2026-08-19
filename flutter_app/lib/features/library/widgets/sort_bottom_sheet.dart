import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// One selectable sort option: a value of type [T] and its display [label].
class SortOption<T> {
  final T value;
  final String label;
  const SortOption(this.value, this.label);
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
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
                style: GoogleFonts.literata(
                    fontSize: 22, color: AppColors.ink500)),
          ),
          for (final option in options)
            ListTile(
              dense: true,
              title: Text(
                option.label,
                style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 14,
                  color: AppColors.ink500,
                  fontWeight: option.value == current
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              trailing: option.value == current
                  ? const Icon(Icons.check, size: 18, color: AppColors.clay400)
                  : null,
              onTap: () => Navigator.pop(sheetContext, option.value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
