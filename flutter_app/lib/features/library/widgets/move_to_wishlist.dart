import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/library_entry.dart';
import '../../../providers/library_provider.dart';

/// Library → Wishlist. Confirms first, since favorite / for-sale flags don't
/// carry over (ratings, notes and play history do).
///
/// Returns true when the game was moved.
Future<bool> confirmAndMoveToWishlist(
    BuildContext context, WidgetRef ref, LibraryEntry entry) async {
  final name = entry.game.name;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Move to wishlist?', style: AppTextStyles.display(size: 22)),
      content: Text(
        'Move "$name" from your library to your wishlist? Your ratings, notes '
        'and logged plays come with it. Favorite and for-sale marks are '
        'cleared.',
        style: AppTextStyles.body(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(libraryProvider.notifier).moveToWishlist(entry);
    messenger.showSnackBar(SnackBar(
      content: Text('$name moved to your wishlist',
          style: AppTextStyles.body(color: Colors.white)),
      backgroundColor: AppColors.forest500,
    ));
    return true;
  } catch (e) {
    // Show the real reason (e.g. a database message) instead of a bare
    // "couldn't move", so failures are diagnosable.
    final reason = e is PostgrestException ? e.message : e.toString();
    messenger.showSnackBar(SnackBar(
      content: Text("Couldn't move $name: $reason",
          style: AppTextStyles.body(color: Colors.white)),
      backgroundColor: AppColors.clay500,
    ));
    return false;
  }
}
