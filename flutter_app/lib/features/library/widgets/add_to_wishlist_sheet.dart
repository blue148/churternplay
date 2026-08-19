import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../providers/wishlist_provider.dart';

/// Opens the "Add to Wishlist" sheet for [game] — the shared Pull action
/// (PRD §13.1) that both the friend-library screen and, later, Push's
/// Accept-suggestion flow route through via `wishlistProvider.addGame`
/// (Open Question #8: one wishlist-insert path, not two).
///
/// Resolves `true` once the game has actually been added, `null`/`false` if
/// the sheet was dismissed without adding — this sheet only performs the
/// insert; the caller decides what navigation (if any) should follow a
/// successful add, since that differs by entry point (e.g. a friend's
/// library screen wants to jump to the Wishlist tab; Push's future Accept
/// action, already on the Wishlist tab, wouldn't).
Future<bool?> showAddToWishlistSheet(
  BuildContext context, {
  required Game game,
  String? prefilledNotes,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AddToWishlistSheet(game: game, prefilledNotes: prefilledNotes),
  );
}

class AddToWishlistSheet extends ConsumerStatefulWidget {
  final Game game;
  final String? prefilledNotes;

  const AddToWishlistSheet({super.key, required this.game, this.prefilledNotes});

  @override
  ConsumerState<AddToWishlistSheet> createState() =>
      _AddToWishlistSheetState();
}

class _AddToWishlistSheetState extends ConsumerState<AddToWishlistSheet> {
  late final _notesCtrl =
      TextEditingController(text: widget.prefilledNotes ?? '');
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(wishlistProvider.notifier).addGame(
            widget.game.id,
            priority: _priority,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${widget.game.name} to your wishlist',
              style: GoogleFonts.atkinsonHyperlegibleNext()),
          backgroundColor: AppColors.forest500,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to add to wishlist. Please try again.',
                style: GoogleFonts.atkinsonHyperlegibleNext())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.parchment50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _gamePreview(game),
                    const SizedBox(height: 20),
                    _priorityField(),
                    const SizedBox(height: 20),
                    _notesField(),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Add to Wishlist',
                  style: GoogleFonts.literata(
                      fontSize: 24, color: AppColors.ink500)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.ink300),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.parchment200),
        ],
      ),
    );
  }

  Widget _gamePreview(Game game) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: game.coverImage != null
              ? CachedNetworkImage(
                  imageUrl: game.coverImage!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.name,
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink500)),
              if (game.publisher != null)
                Text(game.publisher!,
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 12, color: AppColors.ink300)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 48,
        height: 48,
        color: AppColors.parchment100,
        child: const Icon(Icons.menu_book_outlined,
            size: 20, color: AppColors.ink100),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.ink300)),
      );

  Widget _priorityField() {
    const options = [('high', 'High'), ('medium', 'Medium'), ('low', 'Low')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('PRIORITY'),
        Row(
          children: [
            for (final (value, label) in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label,
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 13,
                        color: _priority == value
                            ? Colors.white
                            : AppColors.ink400,
                      )),
                  selected: _priority == value,
                  selectedColor: _priorityColor(value),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.parchment200),
                  onSelected: (_) => setState(() => _priority = value),
                  showCheckmark: false,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _priorityColor(String value) {
    switch (value) {
      case 'high':
        return AppColors.clay400;
      case 'medium':
        return AppColors.wheat400;
      case 'low':
        return AppColors.forest400;
      default:
        return AppColors.ink400;
    }
  }

  Widget _notesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('NOTES (OPTIONAL)'),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any notes about this game…',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.ink100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.ink100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.clay400),
            ),
          ),
          style: GoogleFonts.atkinsonHyperlegibleNext(
              fontSize: 13, color: AppColors.ink500),
        ),
      ],
    );
  }

  Widget _footer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.parchment50,
          border: Border(top: BorderSide(color: AppColors.parchment200)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clay400,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.playlist_add, size: 18),
            label: Text(
              _submitting ? 'Adding…' : 'Add to Wishlist',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
