import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// A labeled section of multi-select [FilterChip]s laid out in a [Wrap].
/// Used for each faceted filter (Publisher, Type, Category, …) in the filter
/// sheet. Renders nothing when [options] is empty.
class FilterChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// When true, option labels are shown with the first letter capitalised
  /// (used for ranking values like "high" → "High").
  final bool capitalize;

  const FilterChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.capitalize = false,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.atkinsonHyperlegibleNext(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.ink300,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(
                  capitalize ? _cap(option) : option,
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 12,
                    color: selected.contains(option)
                        ? Colors.white
                        : AppColors.ink400,
                  ),
                ),
                selected: selected.contains(option),
                onSelected: (_) => onToggle(option),
                selectedColor: AppColors.clay400,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                side: BorderSide(
                  color: selected.contains(option)
                      ? AppColors.clay400
                      : AppColors.parchment200,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
