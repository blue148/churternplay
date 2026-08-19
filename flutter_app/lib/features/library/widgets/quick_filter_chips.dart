import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/library_provider.dart';

/// Horizontal, instant-apply chip row for the highest-frequency facets:
/// Favorites, For Sale, and player counts. Heavier facets live in the full
/// filter sheet.
class QuickFilterChips extends ConsumerWidget {
  const QuickFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            label: 'Favorites',
            icon: Icons.star,
            selected: filter.favoritesOnly,
            onTap: () => notifier.update(
                (f) => f.copyWith(favoritesOnly: !f.favoritesOnly)),
          ),
          _chip(
            label: 'For Sale',
            icon: Icons.sell_outlined,
            selected: filter.forSaleOnly,
            onTap: () => notifier
                .update((f) => f.copyWith(forSaleOnly: !f.forSaleOnly)),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: icon != null
            ? Icon(icon,
                size: 14,
                color: selected ? Colors.white : AppColors.ink300)
            : null,
        label: Text(
          label,
          style: GoogleFonts.atkinsonHyperlegibleNext(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.ink400,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.clay400,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? AppColors.clay400 : AppColors.parchment200,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
