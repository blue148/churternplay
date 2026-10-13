import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shake_gesture/shake_gesture.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/friend.dart';
import '../../data/models/game.dart';
import '../../data/models/library_entry.dart';
import '../../data/services/friend_suggestions_service.dart';
import '../../data/services/friends_service.dart';
import '../../data/services/recent_players_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_suggestions_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recent_players_provider.dart';

// ── Landing menu ───────────────────────────────────────────────────────────────

class GameNiteScreen extends StatelessWidget {
  const GameNiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Nite')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _ToolRow(
            icon: Icons.shuffle,
            iconBg: AppColors.plum100,
            iconColor: AppColors.plum400,
            title: 'Game Picker',
            subtitle: 'Spin the wheel to pick a game',
            onTap: () => context.push('/game-nite/chooser'),
          ),
          _ToolRow(
            icon: Icons.people_outline,
            iconBg: AppColors.clay50,
            iconColor: AppColors.clay400,
            title: 'First Player',
            subtitle: 'Randomly pick who goes first',
            onTap: () => context.push('/game-nite/first-player'),
          ),
          _ToolRow(
            icon: Icons.timer_outlined,
            iconBg: AppColors.forest50,
            iconColor: AppColors.forest400,
            title: 'Turn Timer',
            subtitle: 'Countdown each player\'s turn',
            onTap: () => context.push('/game-nite/turn-timer'),
          ),
          _ToolRow(
            icon: Icons.hourglass_bottom_outlined,
            iconBg: AppColors.wheat50,
            iconColor: AppColors.wheat500,
            title: 'Game Timer',
            subtitle: 'Track a full game session',
            onTap: () => context.push('/game-nite/game-timer'),
          ),
          _ToolRow(
            icon: Icons.casino_outlined,
            iconBg: AppColors.sky50,
            iconColor: AppColors.sky400,
            title: 'Dice Roller',
            subtitle: 'Build a dice pool, then roll or shake',
            onTap: () => context.push('/game-nite/dice-roller'),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(title,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink600)),
          subtitle: Text(subtitle,
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink300)),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.ink200, size: 20),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 84),
      ],
    );
  }
}

// ── Game Picker ────────────────────────────────────────────────────────────────

/// Playtime buckets for the Game Picker filter.
enum _PlaytimeRange {
  under30('Under 30 minutes'),
  thirtyToSixty('30–60 minutes'),
  overHour('Over 1 hour');

  const _PlaytimeRange(this.label);
  final String label;

  /// Whether a game of [minutes] length falls in this bucket. Games with an
  /// unknown playtime never match a specific bucket.
  bool matches(int? minutes) {
    if (minutes == null) return false;
    switch (this) {
      case _PlaytimeRange.under30:
        return minutes < 30;
      case _PlaytimeRange.thirtyToSixty:
        return minutes >= 30 && minutes <= 60;
      case _PlaytimeRange.overHour:
        return minutes > 60;
    }
  }
}

/// A curated, top-level game mechanic for the chooser filter. [keywords] are
/// lowercase substrings matched against the raw BGG mechanic strings stored on
/// each game (e.g. "Area Majority / Influence" → "area-control").
class _Mechanic {
  final String value;
  final String label;
  final List<String> keywords;
  const _Mechanic(this.value, this.label, this.keywords);
}

const _mechanicOptions = <_Mechanic>[
  _Mechanic('worker-placement', 'Worker Placement', ['worker placement']),
  _Mechanic('engine-building', 'Engine Building', ['engine building']),
  _Mechanic('auction-bidding', 'Auction / Bidding', ['auction', 'bidding']),
  _Mechanic('trading-negotiation', 'Trading / Negotiation',
      ['trading', 'negotiation']),
  _Mechanic('deck-building', 'Deck Building',
      ['deck building', 'deck construction', 'deck, bag']),
  _Mechanic('hand-management', 'Hand Management', ['hand management']),
  _Mechanic('drafting', 'Drafting', ['drafting']),
  _Mechanic('trick-taking', 'Trick-Taking', ['trick-taking', 'trick taking']),
  _Mechanic('set-collection', 'Set Collection', ['set collection']),
  _Mechanic('area-control', 'Area Control / Majority',
      ['area majority', 'area control', 'area-impulse', 'influence']),
  _Mechanic('tile-placement', 'Tile Placement',
      ['tile placement', 'tile-laying', 'tile laying']),
  _Mechanic('route-building', 'Route / Network Building',
      ['route', 'network']),
  _Mechanic('dice-rolling', 'Dice Rolling / Placement',
      ['dice rolling', 'dice placement']),
  _Mechanic('push-your-luck', 'Push Your Luck',
      ['push your luck', 'push-your-luck', 'press your luck']),
  _Mechanic('action-points', 'Action Point Allowance', ['action point']),
  _Mechanic('roll-and-write', 'Roll-and-Write',
      ['roll and write', 'roll-and-write', 'flip and write', 'flip-and-write']),
  _Mechanic('cooperative', 'Cooperative',
      ['cooperative', 'co-operative']),
  _Mechanic('hidden-role', 'Hidden Role / Deduction',
      ['hidden role', 'deduction', 'traitor']),
];

/// True when [game] carries a raw mechanic matching the curated [value].
bool _gameHasMechanic(Game game, String value) {
  final mech = _mechanicOptions.firstWhere((m) => m.value == value,
      orElse: () => const _Mechanic('', '', []));
  if (mech.keywords.isEmpty) return false;
  for (final raw in game.gameMechanic) {
    final lower = raw.toLowerCase();
    if (mech.keywords.any(lower.contains)) return true;
  }
  return false;
}

/// One option in an adaptive select (Cupertino wheel on iOS, Material dropdown
/// elsewhere). [value] may be null to represent an "Any" choice.
class _PickerItem<T> {
  final T value;
  final String label;
  const _PickerItem(this.value, this.label);
}

class GameChooserPage extends ConsumerStatefulWidget {
  const GameChooserPage({super.key});

  @override
  ConsumerState<GameChooserPage> createState() => _GameChooserPageState();
}

class _GameChooserPageState extends ConsumerState<GameChooserPage> {
  // ── Library source ────────────────────────────────────────────────────────
  // null = my own library; otherwise the owner id of a friend's shared library
  // (handy when you're at their place playing from their shelf).
  String? _selectedOwnerId;
  List<SharedLibraryAccess> _sharedLibraries = const [];
  List<LibraryEntry> _friendGames = const [];
  bool _loadingFriendGames = false;

  // ── Filters (ported from the web Game Picker) ─────────────────────────────
  int? _playerCount;
  _PlaytimeRange? _playtimeRange;
  String _selectedMechanic = '';

  // Victory intelligence
  bool _favorVictories = false;
  bool _avoidRecentLosses = false;
  bool _onlyPlayedGames = false;

  // The settings panel sits at the top and folds away once a pick is made.
  bool _settingsExpanded = true;

  LibraryEntry? _chosen;

  @override
  void initState() {
    super.initState();
    _loadSharedLibraries();
  }


  Future<void> _loadSharedLibraries() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final libs = await FriendsService.getSharedLibraries(user.id);
      if (mounted) setState(() => _sharedLibraries = libs);
    } catch (_) {
      // Friends' libraries are optional — fall back to just my own.
    }
  }

  /// Switches the picker between my library and a friend's shared shelf.
  Future<void> _selectSource(String? ownerId) async {
    if (ownerId == _selectedOwnerId) return;
    setState(() {
      _selectedOwnerId = ownerId;
      _chosen = null;
      _selectedMechanic = ''; // mechanics differ between libraries
      _friendGames = const [];
    });
    if (ownerId == null) return;
    setState(() => _loadingFriendGames = true);
    try {
      final games = await FriendsService.getSharedLibraryGames(ownerId);
      if (mounted && _selectedOwnerId == ownerId) {
        setState(() {
          _friendGames = games;
          _loadingFriendGames = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedOwnerId == ownerId) {
        setState(() {
          _friendGames = const [];
          _loadingFriendGames = false;
        });
      }
    }
  }

  /// Whether victory intelligence applies — only for my own play history.
  bool get _isOwnLibrary => _selectedOwnerId == null;

  List<LibraryEntry> get _library => _isOwnLibrary
      ? (ref.read(libraryProvider).asData?.value ?? const [])
      : _friendGames;

  bool _matches(LibraryEntry e) {
    final g = e.game;

    if (_playerCount != null) {
      final minP = g.minPlayers ?? 1;
      final maxP = g.maxPlayers ?? 99;
      if (_playerCount! < minP || _playerCount! > maxP) return false;
    }

    if (_playtimeRange != null && !_playtimeRange!.matches(g.playtimeMinutes)) {
      return false;
    }

    if (_selectedMechanic.isNotEmpty &&
        !_gameHasMechanic(g, _selectedMechanic)) {
      return false;
    }

    // Victory-based filters only apply to my own library (a friend's games
    // carry no play history of mine).
    if (_isOwnLibrary) {
      final vs = e.victoryStats;

      if (_onlyPlayedGames) {
        final hasPlays =
            e.playedDates.isNotEmpty || (vs != null && vs.totalSessions > 0);
        if (!hasPlays) return false;
      }

      // Drop games we lose more often than we win when avoiding losing streaks.
      if (_avoidRecentLosses && vs != null && vs.totalSessions > 0) {
        if (vs.winRate < 30) return false;
      }
    }

    return true;
  }

  List<LibraryEntry> get _filteredGames =>
      _library.where(_matches).toList();

  /// Weighted score mirroring the web chooser: base randomness nudged by win
  /// rate, favorites, and recency so the spin feels intelligent.
  double _score(LibraryEntry e) {
    var score = Random().nextDouble();

    // Win history, favorites, and recency are only meaningful for my own
    // library; a friend's shelf gets a plain random pick.
    if (_isOwnLibrary) {
      final vs = e.victoryStats;

      if (_favorVictories && vs != null && vs.totalSessions > 0) {
        score += (vs.winRate / 100) * 0.3;
        if (vs.lastPlayed != null) {
          final days = DateTime.now().difference(vs.lastPlayed!).inDays;
          if (days < 30) score += 0.1;
        }
      }

      if (e.isFavorite) score += 0.15;

      // Discourage repeats: dock games played in the last few days.
      if (e.playedDates.isNotEmpty) {
        final last = e.playedDates.reduce((a, b) => a.isAfter(b) ? a : b);
        final days = DateTime.now().difference(last).inDays;
        if (days < 3) score -= 0.1;
      }
    }

    return max(0, score);
  }

  void _pick() {
    final games = _filteredGames;
    if (games.isEmpty) return;

    // Weighted random selection favouring higher-scoring games.
    final scored = [for (final e in games) (e, _score(e))];
    final total = scored.fold<double>(0, (sum, s) => sum + s.$2);
    var roll = Random().nextDouble() * total;
    var chosen = scored.first.$1;
    for (final s in scored) {
      roll -= s.$2;
      if (roll <= 0) {
        chosen = s.$1;
        break;
      }
    }

    setState(() {
      _chosen = chosen;
      _settingsExpanded = false; // fold the settings away while we reveal.
    });
    HapticFeedback.mediumImpact();
  }

  void _resetFilters() {
    setState(() {
      _playerCount = null;
      _playtimeRange = null;
      _selectedMechanic = '';
      _favorVictories = false;
      _avoidRecentLosses = false;
      _onlyPlayedGames = false;
    });
  }

  int get _activeFilterCount {
    var n = 0;
    if (_playerCount != null) n++;
    if (_playtimeRange != null) n++;
    if (_selectedMechanic.isNotEmpty) n++;
    if (_isOwnLibrary) {
      if (_favorVictories) n++;
      if (_avoidRecentLosses) n++;
      if (_onlyPlayedGames) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    // Watch own library so the panel updates when it loads, even when a
    // friend's shelf is the active source.
    ref.watch(libraryProvider);
    final library = _library;
    final filteredCount = _filteredGames.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Game Picker')),
      body: Column(
        children: [
          _buildSettingsPanel(library, filteredCount),
          Expanded(child: _buildResult()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    filteredCount == 0 || _loadingFriendGames ? null : _pick,
                icon: const Icon(Icons.shuffle),
                label: Text(_chosen == null ? 'Choose Game' : 'Choose Again'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings panel ────────────────────────────────────────────────────────

  Widget _buildSettingsPanel(List<LibraryEntry> library, int filteredCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.parchment50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.parchment200),
      ),
      child: Column(
        children: [
          // Header — tap to fold/unfold.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => _settingsExpanded = !_settingsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 18, color: AppColors.ink400),
                  const SizedBox(width: 10),
                  Text('Game Criteria',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink600)),
                  if (!_settingsExpanded && _activeFilterCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.forest100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$_activeFilterCount',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest600)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                      '$filteredCount ${filteredCount == 1 ? 'game' : 'games'}',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 12, color: AppColors.ink300)),
                  const SizedBox(width: 6),
                  Icon(
                      _settingsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 22,
                      color: AppColors.ink300),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildSettingsBody(library),
            crossFadeState: _settingsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsBody(List<LibraryEntry> library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.parchment200),
          if (_sharedLibraries.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSourceSelector(),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildPlayerStepper()),
              const SizedBox(width: 12),
              Expanded(child: _buildPlaytimeDropdown()),
            ],
          ),
          const SizedBox(height: 14),
          _adaptiveSelect<String>(
            icon: Icons.grid_view_outlined,
            label: 'Core mechanic',
            value: _selectedMechanic,
            items: [
              const _PickerItem('', 'Any'),
              for (final m in _mechanicOptions) _PickerItem(m.value, m.label),
            ],
            onChanged: (v) => setState(() => _selectedMechanic = v),
          ),
          // Victory intelligence keys off my own play history, so it only
          // applies when picking from my library.
          if (_isOwnLibrary) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    size: 16, color: AppColors.wheat400),
                const SizedBox(width: 8),
                Text('VICTORY INTELLIGENCE',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink400)),
              ],
            ),
            const SizedBox(height: 4),
            _switchTile(
              value: _favorVictories,
              title: 'Favor winning games',
              onChanged: (v) => setState(() => _favorVictories = v),
            ),
            _switchTile(
              value: _avoidRecentLosses,
              title: 'Avoid losing streaks',
              onChanged: (v) => setState(() => _avoidRecentLosses = v),
            ),
            _switchTile(
              value: _onlyPlayedGames,
              title: 'Only played games',
              onChanged: (v) => setState(() => _onlyPlayedGames = v),
            ),
          ],
          if (_activeFilterCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.ink400),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(Icons.collections_bookmark_outlined, 'Pick from'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _sourceChip(label: 'My library', ownerId: null),
            for (final lib in _sharedLibraries)
              _sourceChip(
                label: lib.owner?.username ?? 'Friend',
                ownerId: lib.ownerId,
              ),
          ],
        ),
      ],
    );
  }

  Widget _sourceChip({required String label, required String? ownerId}) {
    final selected = _selectedOwnerId == ownerId;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _selectSource(ownerId),
      showCheckmark: false,
      labelStyle: GoogleFonts.atkinsonHyperlegibleNext(
        fontSize: 13,
        color: selected ? AppColors.cream : AppColors.ink500,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      ),
      backgroundColor: AppColors.cream,
      selectedColor: ownerId == null ? AppColors.forest500 : AppColors.plum400,
      side: BorderSide(
          color: selected ? Colors.transparent : AppColors.parchment300),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _fieldLabel(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink500)),
        ],
      );

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink200),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.forest400),
        ),
      );

  static const _maxPlayers = 20;

  /// Player count as a stepper. Below 1 collapses to "Any" (no filter).
  Widget _buildPlayerStepper() {
    final value = _playerCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(Icons.people_outline, 'Players'),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.parchment300),
          ),
          child: Row(
            children: [
              _stepperButton(
                icon: Icons.remove,
                // null → stays Any; 1 → back to Any; else decrement.
                onTap: value == null
                    ? null
                    : () => setState(
                        () => _playerCount = value <= 1 ? null : value - 1),
              ),
              Expanded(
                child: Text(
                  value?.toString() ?? 'Any',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 14,
                    color: value == null ? AppColors.ink200 : AppColors.ink600,
                  ),
                ),
              ),
              _stepperButton(
                icon: Icons.add,
                onTap: (value ?? 0) >= _maxPlayers
                    ? null
                    : () => setState(
                        () => _playerCount = (value ?? 0) + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon,
            size: 18,
            color: onTap == null ? AppColors.ink100 : AppColors.forest500),
      ),
    );
  }

  Widget _buildPlaytimeDropdown() {
    return _adaptiveSelect<_PlaytimeRange?>(
      icon: Icons.timer_outlined,
      label: 'Playtime',
      value: _playtimeRange,
      items: [
        const _PickerItem(null, 'Any'),
        for (final r in _PlaytimeRange.values) _PickerItem(r, r.label),
      ],
      onChanged: (v) => setState(() => _playtimeRange = v),
    );
  }

  /// A select that adapts to the platform: a Cupertino wheel picker in a bottom
  /// modal on iOS (the native iOS idiom), and a Material dropdown menu on
  /// Android and elsewhere (Material has no wheel-picker equivalent).
  Widget _adaptiveSelect<T>({
    required IconData icon,
    required String label,
    required T value,
    required List<_PickerItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final current = items.firstWhere((it) => it.value == value,
        orElse: () => items.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(icon, label),
        const SizedBox(height: 6),
        if (isCupertino)
          GestureDetector(
            onTap: () => _showCupertinoPicker<T>(items, value, onChanged),
            child: InputDecorator(
              decoration: _fieldDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(current.label,
                        style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 14,
                            color: value == null || value == ''
                                ? AppColors.ink400
                                : AppColors.ink600)),
                  ),
                  const Icon(CupertinoIcons.chevron_up_chevron_down,
                      size: 15, color: AppColors.ink200),
                ],
              ),
            ),
          )
        else
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: _fieldDecoration(),
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink600),
            items: [
              for (final it in items)
                DropdownMenuItem(value: it.value, child: Text(it.label)),
            ],
            onChanged: (v) => onChanged(v as T),
          ),
      ],
    );
  }

  void _showCupertinoPicker<T>(
    List<_PickerItem<T>> items,
    T value,
    ValueChanged<T> onChanged,
  ) {
    var index = items.indexWhere((it) => it.value == value);
    if (index < 0) index = 0;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: AppColors.cream,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Toolbar with a Done action to dismiss the wheel.
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.parchment200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Done',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest500)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController:
                      FixedExtentScrollController(initialItem: index),
                  itemExtent: 38,
                  onSelectedItemChanged: (i) => onChanged(items[i].value),
                  children: [
                    for (final it in items)
                      Center(
                        child: Text(it.label,
                            style: GoogleFonts.atkinsonHyperlegibleNext(
                                fontSize: 18, color: AppColors.ink600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink600)),
      activeThumbColor: AppColors.forest500,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────

  /// Name of the active library source, for prompts and labels.
  String? get _activeFriendName {
    if (_isOwnLibrary) return null;
    for (final l in _sharedLibraries) {
      if (l.ownerId == _selectedOwnerId) {
        return l.owner?.username ?? 'your friend';
      }
    }
    return 'your friend';
  }

  Widget _buildResult() {
    if (_loadingFriendGames) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest400),
      );
    }

    final friendName = _activeFriendName;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_chosen != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _chosen!.game.coverImage != null
                    ? Image.network(_chosen!.game.coverImage!,
                        width: 160, height: 213, fit: BoxFit.cover)
                    : Container(
                        width: 160,
                        height: 213,
                        color: AppColors.parchment100,
                        child: const Icon(Icons.menu_book_outlined,
                            size: 48, color: AppColors.ink100)),
              ),
              const SizedBox(height: 20),
              Text(_chosen!.game.name,
                  style: GoogleFonts.literata(
                      fontSize: 26, color: AppColors.ink600),
                  textAlign: TextAlign.center),
              if (friendName != null) ...[
                const SizedBox(height: 8),
                Text('from $friendName’s library',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 13, color: AppColors.plum400)),
              ],
            ] else ...[
              const Icon(Icons.casino_outlined,
                  size: 72, color: AppColors.ink100),
              const SizedBox(height: 24),
              Text(
                  _filteredGames.isEmpty
                      ? 'No games match\nyour criteria'
                      : friendName != null
                          ? 'Set your criteria, then pick\na game from $friendName’s library'
                          : 'Set your criteria, then\npick a game from your library',
                  style: GoogleFonts.literata(
                      fontSize: 22, color: AppColors.ink300),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ── First Player ───────────────────────────────────────────────────────────────

/// Final winner draw uses a cryptographically secure source where the
/// platform provides one, falling back to the default RNG otherwise.
final Random _playerRng = () {
  try {
    return Random.secure();
  } on UnsupportedError {
    return Random();
  }
}();

/// A player chip — carries a stable id so duplicate names still track to the
/// correct card through the shuffle.
class _Player {
  final int id;
  final String name;
  const _Player(this.id, this.name);
}

/// Picks a winning index with a deliberately layered procedure: fold clock
/// jitter and secure-random bits into a running seed, run several
/// Fisher–Yates passes over an index deck, then draw from the top. The draw
/// stays effectively uniform — the extra passes just make it harder to
/// predict and mirror the shuffle the cards perform on screen.
int _drawWinner(int n) {
  if (n <= 1) return 0;
  const mask = 0x1fffffffffffff; // keep within JS-safe integer range
  var seed = DateTime.now().microsecondsSinceEpoch & mask;
  for (var i = 0; i < 8; i++) {
    seed = (seed ^ (seed << 7) ^ _playerRng.nextInt(1 << 24)) & mask;
  }
  final deck = List<int>.generate(n, (i) => i);
  final passes = 3 + _playerRng.nextInt(3);
  for (var p = 0; p < passes; p++) {
    for (var i = n - 1; i > 0; i--) {
      // Advance the seed (LCG) and fold fresh secure bits in each step.
      seed = (seed * 6364136223846793005 + 1442695040888963407) & mask;
      final j = (seed ^ _playerRng.nextInt(1 << 30)) % (i + 1);
      final tmp = deck[i];
      deck[i] = deck[j];
      deck[j] = tmp;
    }
  }
  return deck.first;
}

enum _PickPhase { idle, flipping, shuffling, revealing, done }

class FirstPlayerPage extends ConsumerStatefulWidget {
  const FirstPlayerPage({super.key});

  @override
  ConsumerState<FirstPlayerPage> createState() => _FirstPlayerPageState();
}

class _FirstPlayerPageState extends ConsumerState<FirstPlayerPage>
    with TickerProviderStateMixin {
  final _players = <_Player>[];
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final RecentPlayersStore _recentsService =
      ref.read(recentPlayersStoreProvider);
  late final FriendSuggestionsStore _friendsStore =
      ref.read(friendSuggestionsStoreProvider);
  var _nextId = 0;

  // Previously-used names, most-recent first, for quick re-adding.
  List<String> _recents = const [];

  // Usernames of friends who've shared their library — surfaced as quick-add
  // suggestions alongside recents, badged so they're clearly distinct.
  List<String> _friendNames = const [];

  late final AnimationController _flip;
  late final AnimationController _shuffle;
  late final AnimationController _reveal;
  late final Listenable _anim;

  _PickPhase _phase = _PickPhase.idle;
  _Player? _winner;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  // Per-card flight paths, regenerated each shuffle so it looks fresh.
  final _scatter = <int, _Scatter>{};
  // Where each card is heading: player id -> its post-shuffle grid slot.
  final _toSlot = <int, int>{};

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _shuffle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620));
    _anim = Listenable.merge([_flip, _shuffle, _reveal]);
    _loadRecents();
    _loadFriendNames();
  }

  Future<void> _loadRecents() async {
    try {
      final recents = await _recentsService.load();
      if (mounted) setState(() => _recents = recents);
    } catch (e) {
      // Recents are a convenience — a backend hiccup just leaves them empty.
      debugPrint('First Player: failed to load recent players: $e');
    }
  }

  Future<void> _loadFriendNames() async {
    try {
      final names = await _friendsStore.load();
      if (mounted) setState(() => _friendNames = names);
    } catch (e) {
      // Friend suggestions are best-effort; leave empty on failure.
      debugPrint('First Player: failed to load friend suggestions: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _flip.dispose();
    _shuffle.dispose();
    _reveal.dispose();
    super.dispose();
  }

  bool get _busy =>
      _phase == _PickPhase.flipping ||
      _phase == _PickPhase.shuffling ||
      _phase == _PickPhase.revealing;

  void _addPlayer() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    _ctrl.clear();
    // Keep focus so several players can be typed in a row.
    _focus.requestFocus();
    _commitPlayer(name);
  }

  /// Capitalizes the first letter of each word, leaving the rest untouched so
  /// names like "McCoy" or "O'Brien" keep their casing. Matches the keyboard's
  /// TextCapitalization.words so typed, pasted, and re-added names all agree.
  String _normalizeName(String name) => name
      .split(RegExp(r'(\s+)'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();

  /// Adds a player to the round and remembers the name for next time.
  Future<void> _commitPlayer(String name) async {
    final trimmed = _normalizeName(name.trim());
    if (trimmed.isEmpty || _busy) return;
    setState(() {
      _players.add(_Player(_nextId++, trimmed));
      _resetResult();
    });
    try {
      final updated = await _recentsService.add(trimmed);
      if (mounted) setState(() => _recents = updated);
    } catch (e) {
      // The player is already on the board; only the saved history missed out.
      debugPrint('First Player: failed to save recent player "$trimmed": $e');
    }
  }

  Future<void> _forgetRecent(String name) async {
    try {
      final updated = await _recentsService.remove(name);
      if (mounted) setState(() => _recents = updated);
    } catch (e) {
      // Leave the recents list as-is if the delete didn't reach the backend.
      debugPrint('First Player: failed to forget recent player "$name": $e');
    }
  }

  /// Recent names not already on the board — what the recents picker offers.
  List<String> get _availableRecents {
    final inPlay = _players.map((p) => p.name.toLowerCase()).toSet();
    return _recents.where((n) => !inPlay.contains(n.toLowerCase())).toList();
  }

  /// Friend suggestions not already on the board or already covered by
  /// personal recents.
  List<String> get _availableFriends {
    final inPlay = _players.map((p) => p.name.toLowerCase()).toSet();
    final personal = _recents.map((n) => n.toLowerCase()).toSet();
    return _friendNames
        .where((n) =>
            !inPlay.contains(n.toLowerCase()) &&
            !personal.contains(n.toLowerCase()))
        .toList();
  }

  /// True once neither section has anything left to offer — closes the sheet.
  bool get _quickSelectExhausted =>
      _availableRecents.isEmpty && _availableFriends.isEmpty;

  void _showRecents() {
    _focus.unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        // Rebuilds independently so added/forgotten names drop out live while
        // the sheet stays open for adding several at once.
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final recentNames = _availableRecents;
            final friendNames = _availableFriends;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recentNames.isEmpty && friendNames.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: Text('No recent players to add',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 14, color: AppColors.ink300)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (recentNames.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Text('RECENT PLAYERS',
                                  style: GoogleFonts.atkinsonHyperlegibleNext(
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      color: AppColors.ink400)),
                            ),
                            for (final name in recentNames)
                              ListTile(
                                leading: const Icon(Icons.person_outline,
                                    color: AppColors.clay300),
                                title: Text(name,
                                    style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 15)),
                                trailing: IconButton(
                                  tooltip: 'Forget',
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppColors.ink200),
                                  onPressed: () async {
                                    await _forgetRecent(name);
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {});
                                    if (_quickSelectExhausted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                                ),
                                onTap: () {
                                  _commitPlayer(name);
                                  setSheetState(() {});
                                  if (_quickSelectExhausted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                              ),
                          ],
                          if (friendNames.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 8),
                              child: Text('FROM YOUR FRIENDS',
                                  style: GoogleFonts.atkinsonHyperlegibleNext(
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      color: AppColors.ink400)),
                            ),
                            for (final name in friendNames)
                              ListTile(
                                leading: const Icon(Icons.group_outlined,
                                    color: AppColors.plum400),
                                title: Text(name,
                                    style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 15)),
                                trailing: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('Friend',
                                      style: GoogleFonts.atkinsonHyperlegibleNext(
                                          fontSize: 11,
                                          color: AppColors.plum400)),
                                ),
                                onTap: () {
                                  _commitPlayer(name);
                                  setSheetState(() {});
                                  if (_quickSelectExhausted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removePlayer(int id) {
    if (_busy) return;
    setState(() {
      _players.removeWhere((p) => p.id == id);
      _resetResult();
    });
  }

  void _resetResult() {
    _winner = null;
    _phase = _PickPhase.idle;
    _scatter.clear();
    _toSlot.clear();
    _flip.value = 0;
    _shuffle.value = 0;
    _reveal.value = 0;
  }

  /// Returns every card to its name-up state (keeping the players) so names
  /// can be added or removed before picking again.
  void _reset() {
    if (_busy) return;
    setState(_resetResult);
  }

  void _onShake() {
    if (!mounted || _players.isEmpty || _busy) return;
    // Android's detector can re-fire during one sustained shake; debounce it.
    final now = DateTime.now();
    if (now.difference(_lastShake) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastShake = now;
    _pick();
  }

  Future<void> _pick() async {
    if (_players.isEmpty || _busy) return;
    final n = _players.length;
    final winner = _players[_drawWinner(n)];

    // Assign each card a destination slot (a permutation, so cards genuinely
    // swap places) and a random flight path to roam there.
    final order = List<int>.generate(n, (i) => i)..shuffle(_playerRng);
    _scatter.clear();
    _toSlot.clear();
    for (var i = 0; i < n; i++) {
      final p = _players[i];
      _toSlot[p.id] = order[i];
      _scatter[p.id] = _Scatter.random();
    }

    setState(() {
      _winner = winner;
      _phase = _PickPhase.flipping;
    });
    HapticFeedback.selectionClick();
    await _flip.forward(from: 0);
    if (!mounted) return;

    setState(() => _phase = _PickPhase.shuffling);
    HapticFeedback.lightImpact();
    await _shuffle.forward(from: 0);
    if (!mounted) return;

    // Cards have landed in their shuffled slots — commit the new order so the
    // grid home positions match where they came to rest, then reveal.
    setState(() {
      final reordered = List<_Player?>.filled(n, null);
      for (final p in _players) {
        reordered[_toSlot[p.id]!] = p;
      }
      _players
        ..clear()
        ..addAll(reordered.whereType<_Player>());
      _phase = _PickPhase.revealing;
    });
    HapticFeedback.heavyImpact();
    await _reveal.forward(from: 0);
    if (!mounted) return;

    setState(() => _phase = _PickPhase.done);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy;
    return ShakeGesture(
      onShake: _onShake,
      child: Scaffold(
        appBar: AppBar(title: const Text('First Player')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: enabled,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                        hintText: 'Player name (press return to add)'),
                    style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Recent players',
                  onPressed: enabled && !_quickSelectExhausted
                      ? _showRecents
                      : null,
                  icon: const Icon(Icons.history),
                ),
              ]),
              const SizedBox(height: 16),
              Expanded(child: _buildBoard()),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_phase == _PickPhase.done) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink500,
                            side: const BorderSide(color: AppColors.ink100),
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _players.isEmpty || _busy ? null : _pick,
                      icon: const Icon(Icons.shuffle),
                      label: Text(_phase == _PickPhase.done
                          ? 'Shuffle Again'
                          : 'Pick First Player'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest500,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    if (_players.isEmpty) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline,
                  size: 72, color: AppColors.ink100),
              const SizedBox(height: 24),
              Text('Add players above,\nthen shuffle to pick',
                  style: GoogleFonts.literata(
                      fontSize: 22, color: AppColors.ink300),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    // Absolute positioning is required so cards can fly across the whole
    // board area during the shuffle; a Wrap can't move children freely.
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _BoardLayout.forCount(
            _players.length, constraints.maxWidth, constraints.maxHeight);
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Stack(
            key: const ValueKey('player-cards'),
            clipBehavior: Clip.none,
            children: [
              // The winner is painted last so its enlarged card overlaps the
              // rest; keys keep card state tied to the player as order shifts.
              for (var i = 0; i < _players.length; i++)
                if (_winner?.id != _players[i].id)
                  _buildCard(_players[i], i, layout),
              for (var i = 0; i < _players.length; i++)
                if (_winner?.id == _players[i].id)
                  _buildCard(_players[i], i, layout),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(_Player player, int index, _BoardLayout layout) {
    final isWinner = _winner?.id == player.id;

    // flip: 0 = name showing, 1 = back showing.
    double flip;
    switch (_phase) {
      case _PickPhase.idle:
        flip = 0;
      case _PickPhase.flipping:
        flip = Curves.easeInOut.transform(_flip.value);
      case _PickPhase.shuffling:
        flip = 1;
      case _PickPhase.revealing:
        flip = isWinner ? 1 - Curves.easeInOut.transform(_reveal.value) : 1;
      case _PickPhase.done:
        flip = isWinner ? 0 : 1;
    }

    // Position: cards rest in their grid home, but during the shuffle they
    // travel a path of random waypoints from their old slot to their new one.
    Offset pos;
    var spin = 0.0;
    var travel = 0.0; // 0 at rest, 1 mid-flight — used to dip the scale.
    if (_phase == _PickPhase.shuffling) {
      final sc = _scatter[player.id];
      final from = layout.home(index);
      final to = layout.home(_toSlot[player.id] ?? index);
      final pts = <Offset>[
        from,
        if (sc != null) ...sc.points(layout),
        to,
      ];
      pos = _alongPath(pts, _shuffle.value);
      // Whole-turn spins land back upright (a multiple of 2π) at t = 1.
      final spins = sc?.spins ?? 1;
      final dir = sc?.spinDir ?? 1;
      spin = dir * _shuffle.value * 2 * pi * spins;
      travel = sin(pi * _shuffle.value);
    } else {
      pos = layout.home(index);
    }

    // Winner grows 50% and rises above the rest on reveal; losers dim back.
    final revealT = _phase == _PickPhase.revealing
        ? Curves.easeOut.transform(_reveal.value)
        : (_phase == _PickPhase.done ? 1.0 : 0.0);
    // As it grows, the winner drifts to board centre so it never crowds the
    // controls below.
    if (isWinner && _phase != _PickPhase.shuffling) {
      pos = Offset.lerp(pos, layout.center, revealT)!;
    }
    final scale = (isWinner ? 1 + 0.5 * revealT : 1 - 0.04 * revealT) *
        (1 - 0.12 * travel);
    final dim = isWinner ? 1.0 : 1 - 0.55 * revealT;

    Widget content = Transform.rotate(
      angle: spin,
      child: Transform.scale(
        scale: scale,
        child: Opacity(opacity: dim, child: _flipCard(player, flip, isWinner)),
      ),
    );

    // A delete affordance is only offered while idle, so it never collides
    // with the flip/shuffle choreography.
    if (_phase == _PickPhase.idle) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.cancel, color: AppColors.ink200),
              onPressed: () => _removePlayer(player.id),
            ),
          ),
        ],
      );
    }

    return Positioned(
        key: ValueKey(player.id), left: pos.dx, top: pos.dy, child: content);
  }

  /// Eased lerp along a polyline of points as `t` runs 0 → 1.
  Offset _alongPath(List<Offset> pts, double t) {
    if (pts.length == 1) return pts.first;
    final segs = pts.length - 1;
    final scaled = (t * segs).clamp(0.0, segs.toDouble());
    var seg = scaled.floor();
    if (seg >= segs) seg = segs - 1;
    final local = Curves.easeInOut.transform(scaled - seg);
    return Offset.lerp(pts[seg], pts[seg + 1], local)!;
  }

  Widget _flipCard(_Player player, double flip, bool isWinner) {
    final showBack = flip > 0.5;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateY(flip * pi);
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: showBack
          // Counter-rotate so the back face reads the right way round.
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(pi),
              child: const _CardBack(),
            )
          : _CardFront(name: player.name, highlight: isWinner),
    );
  }
}

const _cardW = 104.0;
const _cardH = 140.0;
const _cardGap = 16.0;

/// Grid geometry for the card board: where each slot sits and how far a card
/// may roam while still staying fully on screen.
class _BoardLayout {
  final int cols;
  final double startX;
  final double startY;
  final double areaW;
  final double areaH;

  const _BoardLayout({
    required this.cols,
    required this.startX,
    required this.startY,
    required this.areaW,
    required this.areaH,
  });

  factory _BoardLayout.forCount(int n, double w, double h) {
    var cols = ((w + _cardGap) / (_cardW + _cardGap)).floor();
    cols = cols.clamp(1, n < 1 ? 1 : n);
    final rows = (n / cols).ceil();
    final gridW = cols * _cardW + (cols - 1) * _cardGap;
    final gridH = rows * _cardH + (rows - 1) * _cardGap;
    return _BoardLayout(
      cols: cols,
      startX: ((w - gridW) / 2).clamp(0.0, w),
      startY: ((h - gridH) / 2).clamp(0.0, h),
      areaW: (w - _cardW).clamp(0.0, w),
      areaH: (h - _cardH).clamp(0.0, h),
    );
  }

  Offset home(int slot) {
    final col = slot % cols;
    final row = slot ~/ cols;
    return Offset(
        startX + col * (_cardW + _cardGap), startY + row * (_cardH + _cardGap));
  }

  /// Maps a normalized (0..1) waypoint to an on-screen top-left position.
  Offset scatterPoint(Offset fraction) =>
      Offset(fraction.dx * areaW, fraction.dy * areaH);

  /// Top-left that places a card dead-centre in the board.
  Offset get center => Offset(areaW / 2, areaH / 2);
}

/// A card's shuffle flight: a few random waypoints (in 0..1 board fractions)
/// plus a spin so it tumbles as it travels.
class _Scatter {
  final List<Offset> waypoints;
  final int spins;
  final double spinDir;
  const _Scatter(this.waypoints, this.spins, this.spinDir);

  factory _Scatter.random() {
    final count = 2 + _playerRng.nextInt(2); // 2–3 waypoints
    return _Scatter(
      [
        for (var i = 0; i < count; i++)
          Offset(_playerRng.nextDouble(), _playerRng.nextDouble()),
      ],
      1 + _playerRng.nextInt(2),
      _playerRng.nextBool() ? 1 : -1,
    );
  }

  List<Offset> points(_BoardLayout layout) =>
      [for (final f in waypoints) layout.scatterPoint(f)];
}

class _CardFront extends StatelessWidget {
  final String name;
  final bool highlight;
  const _CardFront({required this.name, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardW,
      height: _cardH,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.forest50 : AppColors.parchment50,
        border: Border.all(
            color: highlight ? AppColors.forest400 : AppColors.parchment300,
            width: highlight ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(highlight ? Icons.emoji_events_outlined : Icons.person_outline,
              size: 30,
              color: highlight ? AppColors.forest500 : AppColors.clay300),
          const SizedBox(height: 12),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                  fontSize: 20,
                  height: 1.05,
                  color: highlight ? AppColors.forest600 : AppColors.ink600)),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardW,
      height: _cardH,
      decoration: BoxDecoration(
        color: AppColors.clay400,
        border: Border.all(color: AppColors.clay500, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Container(
          width: _cardW - 24,
          height: _cardH - 24,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.clay100, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.casino_outlined,
              size: 32, color: AppColors.clay100),
        ),
      ),
    );
  }
}

// ── Turn Timer ─────────────────────────────────────────────────────────────────

typedef _TurnPreset = ({String label, int seconds});

const List<_TurnPreset> _kTurnPresets = [
  (label: '30s', seconds: 30),
  (label: '1 min', seconds: 60),
  (label: '2 min', seconds: 120),
  (label: '3 min', seconds: 180),
  (label: '5 min', seconds: 300),
];

class TurnTimerPage extends StatefulWidget {
  const TurnTimerPage({super.key});

  @override
  State<TurnTimerPage> createState() => _TurnTimerPageState();
}

class _TurnTimerPageState extends State<TurnTimerPage> {
  int _seconds = 60;
  int _remaining = 60;
  bool _running = false;
  StreamSubscription<int>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _remaining = _seconds;
      _running = true;
    });
    _sub = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          _running = false;
          _sub?.cancel();
          HapticFeedback.vibrate();
        }
      });
    });
  }

  void _reset() {
    _sub?.cancel();
    setState(() {
      _remaining = _seconds;
      _running = false;
    });
  }

  String get _display {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turn Timer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_display,
                  style: GoogleFonts.dmMono(
                      fontSize: 72,
                      color: _remaining == 0
                          ? AppColors.clay400
                          : AppColors.ink600,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 24),
              if (!_running) ...[
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final preset in _kTurnPresets)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _seconds == preset.seconds,
                        showCheckmark: false,
                        labelStyle: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _seconds == preset.seconds
                                ? Colors.white
                                : AppColors.ink500),
                        selectedColor: AppColors.forest500,
                        backgroundColor: AppColors.parchment50,
                        side: BorderSide(
                            color: _seconds == preset.seconds
                                ? AppColors.forest500
                                : AppColors.parchment300),
                        onSelected: (_) => setState(() {
                          _seconds = preset.seconds;
                          _remaining = preset.seconds;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Duration: $_seconds seconds',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 13, color: AppColors.ink300)),
                Slider(
                  value: _seconds.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  activeColor: AppColors.forest500,
                  onChanged: (v) => setState(() {
                    _seconds = v.toInt();
                    _remaining = _seconds;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_running)
                    OutlinedButton(
                        onPressed: _reset, child: const Text('Reset'))
                  else
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest500,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Timer ─────────────────────────────────────────────────────────────────

class GameTimerPage extends StatefulWidget {
  const GameTimerPage({super.key});

  @override
  State<GameTimerPage> createState() => _GameTimerPageState();
}

class _GameTimerPageState extends State<GameTimerPage> {
  int _elapsed = 0;
  bool _running = false;
  StreamSubscription<int>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _sub?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _sub = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
        if (mounted) setState(() => _elapsed++);
      });
    }
  }

  void _reset() {
    _sub?.cancel();
    setState(() {
      _elapsed = 0;
      _running = false;
    });
  }

  String get _display {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Timer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_display,
                  style: GoogleFonts.dmMono(
                      fontSize: 72,
                      color: AppColors.ink600,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label: Text(_running
                        ? 'Pause'
                        : (_elapsed == 0 ? 'Start' : 'Resume')),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest500,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14)),
                  ),
                  if (_elapsed > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                        onPressed: _reset, child: const Text('Reset')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
