import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/library_entry.dart';
import '../../../data/models/session_victory.dart';
import '../../../data/services/sessions_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/recent_players_provider.dart';

/// Opens the "Log a Play" sheet for [entry] — records a game session with
/// per-player results, mirroring the web app's victory-log flow.
Future<void> showLogPlaySheet(BuildContext context, LibraryEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LogPlaySheet(entry: entry),
  );
}

class _PlayerInput {
  _PlayerInput({required this.id, this.name = ''});
  final int id;
  String name;
  bool isWinner = false;
  int? score;
  int? placement;
}

class LogPlaySheet extends ConsumerStatefulWidget {
  const LogPlaySheet({super.key, required this.entry});

  final LibraryEntry entry;

  @override
  ConsumerState<LogPlaySheet> createState() => _LogPlaySheetState();
}

class _LogPlaySheetState extends ConsumerState<LogPlaySheet> {
  final _notesCtrl = TextEditingController();
  final _players = <_PlayerInput>[];
  var _nextId = 1;

  DateTime _sessionDate = DateTime.now();
  int? _durationMinutes;
  bool _submitting = false;
  List<String> _recents = const [];

  @override
  void initState() {
    super.initState();
    _players.add(_PlayerInput(id: 0, name: 'Me'));
    _loadRecents();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    try {
      final recents = await ref.read(recentPlayersStoreProvider).load();
      if (mounted) setState(() => _recents = recents);
    } catch (_) {
      // Recents are a convenience — fall back to manual entry only.
    }
  }

  List<String> get _availableRecents {
    final inPlay = _players.map((p) => p.name.trim().toLowerCase()).toSet();
    return _recents.where((n) => !inPlay.contains(n.toLowerCase())).toList();
  }

  void _addPlayer([String name = '']) {
    setState(() => _players.add(_PlayerInput(id: _nextId++, name: name)));
  }

  void _removePlayer(int id) {
    if (_players.length <= 1) return;
    setState(() => _players.removeWhere((p) => p.id == id));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sessionDate),
    );
    if (time == null) return;
    setState(() {
      _sessionDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<bool> _confirmNoWinner() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('No winners selected',
            style: GoogleFonts.literata(fontSize: 22)),
        content: Text(
          'Log this session without marking a winner?',
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Continue',
                style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.clay500)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final validPlayers =
        _players.where((p) => p.name.trim().isNotEmpty).toList();
    if (validPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Add at least one player', style: GoogleFonts.atkinsonHyperlegibleNext())),
      );
      return;
    }

    if (!validPlayers.any((p) => p.isWinner)) {
      final proceed = await _confirmNoWinner();
      if (!proceed || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      final session = await SessionsService.createSession(
        userId: user.id,
        gameId: widget.entry.gameId,
        sessionDate: _sessionDate,
        durationMinutes: _durationMinutes,
        playerCount: validPlayers.length,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final victories = [
        for (final p in validPlayers)
          SessionVictory(
            id: '',
            sessionId: '',
            playerName: p.name.trim(),
            isWinner: p.isWinner,
            score: p.score,
            placement: p.placement,
            createdAt: DateTime.now(),
          ),
      ];
      await SessionsService.addMultipleVictories(session.id, victories);

      // Best-effort: remember these names for next time's recents picker.
      final recentsStore = ref.read(recentPlayersStoreProvider);
      for (final p in validPlayers) {
        unawaited(recentsStore.add(p.name.trim()));
      }

      await ref
          .read(libraryProvider.notifier)
          .recordPlayedDate(widget.entry.id, _sessionDate);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged play for ${widget.entry.game.name}',
              style: GoogleFonts.atkinsonHyperlegibleNext()),
          backgroundColor: AppColors.forest500,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to log play. Please try again.',
                style: GoogleFonts.atkinsonHyperlegibleNext())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.entry.game;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _dateTimeField()),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _durationField()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _playersSection(),
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
              Text('Log a Play',
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
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink300)),
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

  InputDecoration _fieldDecoration({String? hint, EdgeInsets? padding}) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      );

  Widget _dateTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('DATE & TIME'),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickDateTime,
          child: InputDecorator(
            decoration: _fieldDecoration(),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.ink300),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(_sessionDate),
                  style:
                      GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _durationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('DURATION (MIN)'),
        TextField(
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration(hint: 'Optional'),
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink500),
          onChanged: (v) =>
              _durationMinutes = v.trim().isEmpty ? null : int.tryParse(v),
        ),
      ],
    );
  }

  Widget _notesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('NOTES (OPTIONAL)'),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: _fieldDecoration(hint: 'Any notes about this session…'),
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink500),
        ),
      ],
    );
  }

  Widget _playersSection() {
    final recents = _availableRecents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label('PLAYERS (${_players.length})'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addPlayer(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Player'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.clay400,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (recents.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in recents)
                ActionChip(
                  label: Text(name, style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12)),
                  avatar: const Icon(Icons.history, size: 14),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.parchment100,
                  side: BorderSide.none,
                  onPressed: () => _addPlayer(name),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final player in _players) _playerRow(player),
      ],
    );
  }

  Widget _playerRow(_PlayerInput player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: player.name,
              decoration: _fieldDecoration(hint: 'Player name'),
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink500),
              onChanged: (v) => player.name = v,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => player.isWinner = !player.isWinner),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: player.isWinner ? AppColors.wheat100 : AppColors.parchment100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: player.isWinner
                      ? AppColors.wheat300
                      : AppColors.parchment200,
                ),
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: player.isWinner ? AppColors.wheat500 : AppColors.ink200,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: TextFormField(
              initialValue: player.score?.toString(),
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(
                  hint: 'Score',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink500),
              onChanged: (v) =>
                  player.score = v.trim().isEmpty ? null : int.tryParse(v),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: TextFormField(
              initialValue: player.placement?.toString(),
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(
                  hint: '#',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink500),
              onChanged: (v) =>
                  player.placement = v.trim().isEmpty ? null : int.tryParse(v),
            ),
          ),
          if (_players.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: AppColors.ink200),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _removePlayer(player.id),
            ),
        ],
      ),
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
                : const Icon(Icons.emoji_events_outlined, size: 18),
            label: Text(
              _submitting ? 'Logging…' : 'Log Play',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
