import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend.dart';
import '../../../data/models/game.dart';
import '../../../data/services/friends_service.dart';
import '../../../data/services/suggestions_service.dart';
import 'friend_row.dart';

/// Opens the "Suggest to a Friend" sheet for [game] — Push (PRD §13.2).
/// Resolves `true` once a suggestion has actually been sent.
Future<bool?> showSuggestToFriendSheet(
  BuildContext context, {
  required Game game,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SuggestToFriendSheet(game: game),
  );
}

class SuggestToFriendSheet extends ConsumerStatefulWidget {
  final Game game;

  const SuggestToFriendSheet({super.key, required this.game});

  @override
  ConsumerState<SuggestToFriendSheet> createState() =>
      _SuggestToFriendSheetState();
}

class _SuggestToFriendSheetState extends ConsumerState<SuggestToFriendSheet> {
  final _notesCtrl = TextEditingController();
  List<UserFriend> _friends = [];
  bool _loadingFriends = true;
  String? _selectedFriendId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final friends = await FriendsService.getUserFriends(user.id);
      if (mounted) {
        setState(() {
          _friends = friends;
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _send() async {
    final user = supabase.auth.currentUser;
    final recipientId = _selectedFriendId;
    if (user == null || recipientId == null) return;
    setState(() => _sending = true);
    try {
      await SuggestionsService.sendSuggestion(
        user.id,
        recipientId,
        widget.game.id,
        note: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suggested ${widget.game.name}',
              style: GoogleFonts.atkinsonHyperlegibleNext()),
          backgroundColor: AppColors.forest500,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send suggestion. Please try again.',
                style: GoogleFonts.atkinsonHyperlegibleNext())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
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
                child: _loadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : _friends.isEmpty
                        ? _emptyState()
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            children: [
                              _gamePreview(widget.game),
                              const SizedBox(height: 20),
                              _label('SEND TO'),
                              ..._friends.map(_friendRow),
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

  Widget _friendRow(UserFriend f) {
    final friend = f.friend;
    final selected = friend != null && friend.id == _selectedFriendId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FriendRow(
        username: friend?.username ?? 'Unknown',
        avatarUrl: friend?.avatarUrl,
        totalGames: friend?.totalGames ?? 0,
        onTap: friend == null
            ? null
            : () => setState(() => _selectedFriendId = friend.id),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? AppColors.forest500 : AppColors.ink200,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 48, color: AppColors.ink100),
          const SizedBox(height: 16),
          Text('No friends yet',
              style: GoogleFonts.literata(fontSize: 22, color: AppColors.ink300)),
          const SizedBox(height: 8),
          Text('Add friends from Profile → Friends',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 13, color: AppColors.ink200)),
        ],
      ),
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
              Text('Suggest to a Friend',
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

  Widget _notesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('NOTE (OPTIONAL)'),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Why they might like this one…',
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
            onPressed: (_sending || _selectedFriendId == null) ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clay400,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(
              _sending ? 'Sending…' : 'Send Suggestion',
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
