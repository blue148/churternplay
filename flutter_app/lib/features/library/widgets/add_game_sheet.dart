import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../manual_game_entry_page.dart';

/// Bottom sheet for adding a game by scan or title search. A Library /
/// Wishlist toggle at the top chooses where the game ends up; pass
/// [initialToWishlist] to open with Wishlist selected.
void showAddGameSheet(BuildContext context, {bool initialToWishlist = false}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.parchment50,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        _AddGameSheet(parentContext: context, initialToWishlist: initialToWishlist),
  );
}

class _AddGameSheet extends StatefulWidget {
  const _AddGameSheet(
      {required this.parentContext, required this.initialToWishlist});

  final BuildContext parentContext;
  final bool initialToWishlist;

  @override
  State<_AddGameSheet> createState() => _AddGameSheetState();
}

class _AddGameSheetState extends State<_AddGameSheet> {
  late bool _toWishlist = widget.initialToWishlist;

  void _go(void Function(BuildContext parent) navigate) {
    final parent = widget.parentContext;
    Navigator.pop(context);
    navigate(parent);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Add a game',
                style: AppTextStyles.display(size: 22, weight: FontWeight.w400)
                    .copyWith(color: AppColors.ink500)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.collections_bookmark_outlined),
                    label: Text('Library')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.favorite_border),
                    label: Text('Wishlist')),
              ],
              selected: {_toWishlist},
              onSelectionChanged: (s) => setState(() => _toWishlist = s.first),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.photo_camera_outlined, color: AppColors.clay400),
            title: Text('Scan title or barcode',
                style: AppTextStyles.body(
                    weight: FontWeight.w600, color: AppColors.ink500)),
            subtitle: Text('Snap the box or scan its barcode',
                style: AppTextStyles.body(size: 12, color: AppColors.ink300)),
            onTap: () => _go((parent) => parent.push(
                _toWishlist ? '/library/scanner?to=wishlist' : '/library/scanner')),
          ),
          ListTile(
            leading: const Icon(Icons.search, color: AppColors.clay400),
            title: Text('Search by title',
                style: AppTextStyles.body(
                    weight: FontWeight.w600, color: AppColors.ink500)),
            subtitle: Text('Find a game on BoardGameGeek',
                style: AppTextStyles.body(size: 12, color: AppColors.ink300)),
            onTap: () => _go((parent) => parent.push('/library/manual-add',
                extra: ManualAddArgs(toWishlist: _toWishlist))),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
