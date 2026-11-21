import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/recent_players_provider.dart';
import 'score_calculator.dart';

/// Game Nite → Score Calculator. A simple calculator whose result can be
/// added to a chosen player's running total. Totals can be reset, and the
/// whole player list cleared once the scores are done.
class ScoreCalculatorPage extends ConsumerStatefulWidget {
  const ScoreCalculatorPage({super.key});

  @override
  ConsumerState<ScoreCalculatorPage> createState() =>
      _ScoreCalculatorPageState();
}

class _ScoreCalculatorPageState extends ConsumerState<ScoreCalculatorPage> {
  static const _maxPlayers = 12;
  static const _maxExpressionLength = 40;

  final _nameCtrl = TextEditingController();
  final _players = <ScorePlayer>[];
  int _nextId = 1;
  int? _selectedId;
  String _expr = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultPlayers();
  }

  /// Starts from the last First Player set, unless the user already added
  /// someone while it loaded.
  Future<void> _loadDefaultPlayers() async {
    try {
      final names = await ref.read(lastPlayerSetStoreProvider).load();
      if (!mounted || _players.isNotEmpty || names.isEmpty) return;
      setState(() {
        for (final name in names.take(_maxPlayers)) {
          _players.add(ScorePlayer(id: _nextId++, name: name));
        }
        _selectedId = _players.first.id;
      });
    } catch (_) {
      // A convenience only — start with an empty board.
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  ScorePlayer? get _selected {
    for (final p in _players) {
      if (p.id == _selectedId) return p;
    }
    return null;
  }

  double? get _value => evaluateExpression(_expr);

  // ── Players ────────────────────────────────────────────────────────────────

  void _addPlayer() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _players.length >= _maxPlayers) return;
    setState(() {
      final p = ScorePlayer(id: _nextId++, name: name);
      _players.add(p);
      _selectedId = p.id;
      _nameCtrl.clear();
    });
  }

  void _removePlayer(ScorePlayer p) {
    setState(() {
      _players.remove(p);
      if (_selectedId == p.id) {
        _selectedId = _players.isEmpty ? null : _players.last.id;
      }
    });
  }

  // ── Calculator ─────────────────────────────────────────────────────────────

  static const _operators = {'+', '−', '×', '÷'};

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_operators.contains(key)) {
        if (_expr.isEmpty) {
          if (key == '−') _expr = '−';
          return;
        }
        final last = _expr[_expr.length - 1];
        // Typing a new operator replaces a trailing one.
        if (_operators.contains(last)) {
          _expr = _expr.substring(0, _expr.length - 1) + key;
        } else if (_expr.length < _maxExpressionLength) {
          _expr += key;
        }
        return;
      }
      if (_expr.length >= _maxExpressionLength) return;
      if (key == '.') {
        // One decimal point per number.
        final lastNumber = _expr.split(RegExp('[+−×÷]')).last;
        if (lastNumber.contains('.')) return;
        _expr += lastNumber.isEmpty ? '0.' : '.';
        return;
      }
      _expr += key;
    });
  }

  void _backspace() => setState(() {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      });

  void _clearEntry() => setState(() => _expr = '');

  void _equals() {
    final v = _value;
    if (v == null) return;
    setState(() => _expr = v < 0 ? '−${formatScore(-v)}' : formatScore(v));
  }

  void _toggleSign() => setState(() {
        if (_expr.startsWith('−')) {
          _expr = _expr.substring(1);
        } else if (_expr.isNotEmpty) {
          _expr = '−$_expr';
        }
      });

  void _addToPlayer() {
    final player = _selected;
    final v = _value;
    if (player == null || v == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      player.entries.add(v);
      _expr = '';
    });
  }

  void _undoLast(ScorePlayer p) {
    if (p.entries.isEmpty) return;
    setState(() => p.entries.removeLast());
  }

  // ── Clearing ───────────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppFonts.serif(fontSize: 22)),
        content: Text(body, style: AppFonts.sans(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action,
                  style: AppFonts.sans(color: AppColors.clay500))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _resetScores() async {
    if (!await _confirm('Reset all scores?',
        'Every player goes back to 0. Players stay on the board.', 'Reset')) {
      return;
    }
    setState(() {
      for (final p in _players) {
        p.entries.clear();
      }
      _expr = '';
    });
  }

  Future<void> _clearPlayers() async {
    if (!await _confirm('Clear all players?',
        'This removes every player and their scores.', 'Clear players')) {
      return;
    }
    setState(() {
      _players.clear();
      _selectedId = null;
      _expr = '';
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment50,
      appBar: AppBar(
        title: const Text('Score Calculator'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            enabled: _players.isNotEmpty,
            onSelected: (v) => v == 'reset' ? _resetScores() : _clearPlayers(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset all scores')),
              PopupMenuItem(value: 'clear', child: Text('Clear all players')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _addPlayerRow(),
            Expanded(child: _playerList()),
            if (_players.isNotEmpty) _clearBar(),
            _calculator(),
          ],
        ),
      ),
    );
  }

  Widget _addPlayerRow() {
    final full = _players.length >= _maxPlayers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              enabled: !full,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 24,
              onSubmitted: (_) => _addPlayer(),
              decoration: InputDecoration(
                hintText: full ? 'Player limit reached' : 'Add a player',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: full ? null : _addPlayer,
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _playerList() {
    if (_players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Add players, pick one, then use the calculator to add points '
            'to their score.',
            textAlign: TextAlign.center,
            style: AppFonts.sans(fontSize: 14, color: AppColors.ink300),
          ),
        ),
      );
    }
    final best = _players.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: _players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = _players[i];
        final selected = p.id == _selectedId;
        final leading = p.entries.isNotEmpty && p.total == best;
        return Material(
          color: selected ? AppColors.forest50 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
                color: selected ? AppColors.forest400 : AppColors.parchment200,
                width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedId = p.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  if (leading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.emoji_events,
                          size: 20, color: AppColors.wheat400),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink600)),
                        if (p.entries.isNotEmpty)
                          Text(
                            p.entries.map(formatScore).join(' + '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sans(
                                fontSize: 12, color: AppColors.ink300),
                          ),
                      ],
                    ),
                  ),
                  Text(formatScore(p.total),
                      style: AppFonts.serif(
                          fontSize: 28, color: AppColors.ink600)),
                  IconButton(
                    tooltip: 'Undo last entry for ${p.name}',
                    icon: const Icon(Icons.undo, size: 20),
                    onPressed: p.entries.isEmpty ? null : () => _undoLast(p),
                  ),
                  IconButton(
                    tooltip: 'Remove ${p.name}',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removePlayer(p),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _clearBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetScores,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset scores'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearPlayers,
              icon: const Icon(Icons.group_remove_outlined, size: 18),
              label: const Text('Clear players'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculator() {
    final player = _selected;
    final value = _value;
    final canAdd = player != null && value != null;
    final preview = value == null
        ? ''
        : (RegExp('[+−×÷]').hasMatch(_expr.substring(_expr.isEmpty ? 0 : 1))
            ? '= ${formatScore(value)}'
            : '');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.parchment100,
        border: Border(top: BorderSide(color: AppColors.parchment300)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            label: _expr.isEmpty ? 'Display empty' : 'Display $_expr $preview',
            child: ExcludeSemantics(
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.parchment200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 16,
                      child: Text(preview,
                          style: AppFonts.sans(
                              fontSize: 13, color: AppColors.ink300)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_expr.isEmpty ? '0' : _expr,
                          maxLines: 1,
                          style: AppFonts.serif(
                              fontSize: 28,
                              color: _expr.isEmpty
                                  ? AppColors.ink200
                                  : AppColors.ink600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _keyRow([
            _Key('C', onTap: _clearEntry, tone: _Tone.action, label: 'Clear'),
            _Key('⌫',
                onTap: _backspace, tone: _Tone.action, label: 'Backspace'),
            _Key('÷', onTap: () => _press('÷'), tone: _Tone.op, label: 'Divide'),
            _Key('×',
                onTap: () => _press('×'), tone: _Tone.op, label: 'Multiply'),
          ]),
          _keyRow([
            _digit('7'), _digit('8'), _digit('9'),
            _Key('−',
                onTap: () => _press('−'), tone: _Tone.op, label: 'Minus'),
          ]),
          _keyRow([
            _digit('4'), _digit('5'), _digit('6'),
            _Key('+', onTap: () => _press('+'), tone: _Tone.op, label: 'Plus'),
          ]),
          _keyRow([
            _digit('1'), _digit('2'), _digit('3'),
            _Key('=', onTap: _equals, tone: _Tone.op, label: 'Equals'),
          ]),
          _keyRow([
            _Key('±',
                onTap: _toggleSign, tone: _Tone.action, label: 'Toggle sign'),
            _digit('0'),
            _Key('.', onTap: () => _press('.'), label: 'Decimal point'),
            _Key('', onTap: null, tone: _Tone.action, label: ''),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: canAdd ? _addToPlayer : null,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.clay400),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                player == null
                    ? 'Select a player'
                    : value == null
                        ? 'Enter a number for ${player.name}'
                        : 'Add ${formatScore(value)} to ${player.name}',
                style: AppFonts.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _Key _digit(String d) => _Key(d, onTap: () => _press(d), label: d);

  Widget _keyRow(List<_Key> keys) => Row(
        children: [
          for (final k in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: k.build(),
              ),
            ),
        ],
      );
}

enum _Tone { digit, op, action }

class _Key {
  _Key(this.text, {required this.onTap, this.tone = _Tone.digit, this.label});

  final String text;
  final VoidCallback? onTap;
  final _Tone tone;
  final String? label;

  Widget build() {
    if (text.isEmpty) return const SizedBox(height: 40);
    final bg = switch (tone) {
      _Tone.digit => Colors.white,
      _Tone.op => AppColors.forest100,
      _Tone.action => AppColors.parchment200,
    };
    return Semantics(
      button: true,
      label: label ?? text,
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: Text(text,
                  style: AppFonts.sans(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink600)),
            ),
          ),
        ),
      ),
    );
  }
}
