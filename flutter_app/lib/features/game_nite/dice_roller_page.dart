import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shake_gesture/shake_gesture.dart';

import '../../core/theme/app_colors.dart';

const _dieTypes = [4, 6, 8, 10, 20];
const _maxPerType = 10;
const _maxTotalDice = 20;

/// Final roll results use a cryptographically secure source where the
/// platform provides one; cosmetic mid-animation faces use a cheap RNG.
final Random _rng = _makeRng();
final Random _cosmeticRng = Random();

Random _makeRng() {
  try {
    return Random.secure();
  } on UnsupportedError {
    return Random();
  }
}

class _RolledDie {
  final int sides;
  final int value;
  int tempValue;
  bool settled;
  final double phase;
  final double settleAt;

  _RolledDie({
    required this.sides,
    required this.value,
    required this.tempValue,
    required this.phase,
    required this.settleAt,
    this.settled = false,
  });
}

// ── Dice Roller ────────────────────────────────────────────────────────────────

class DiceRollerPage extends StatefulWidget {
  const DiceRollerPage({super.key});

  @override
  State<DiceRollerPage> createState() => _DiceRollerPageState();
}

class _DiceRollerPageState extends State<DiceRollerPage>
    with SingleTickerProviderStateMixin {
  final Map<int, int> _counts = {for (final s in _dieTypes) s: 0};
  List<_RolledDie> _dice = [];
  int? _total;
  int _lastTick = -1;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  late final AnimationController _controller;

  int get _poolSize => _counts.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onShake() {
    if (!mounted) return;
    // Android's detector can re-fire during one sustained shake; debounce it.
    final now = DateTime.now();
    if (now.difference(_lastShake) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastShake = now;
    _roll();
  }

  void _roll() {
    final n = _poolSize;
    if (n == 0 || _controller.isAnimating) return;
    final dice = <_RolledDie>[];
    var i = 0;
    for (final sides in _dieTypes) {
      for (var c = 0; c < _counts[sides]!; c++) {
        dice.add(_RolledDie(
          sides: sides,
          value: _rng.nextInt(sides) + 1,
          tempValue: _cosmeticRng.nextInt(sides) + 1,
          phase: _cosmeticRng.nextDouble() * 2 * pi,
          // Staggered: first die settles ~55% in, last exactly at the end.
          settleAt: 0.55 + 0.45 * ((i + 1) / n),
        ));
        i++;
      }
    }
    setState(() {
      _dice = dice;
      _total = null;
    });
    HapticFeedback.lightImpact();
    _lastTick = -1;
    _controller.forward(from: 0);
  }

  void _onTick() {
    // The per-die AnimatedBuilders repaint every frame; this listener only
    // mutates face values (~every 80ms) and marks dice settled.
    final t = _controller.value;
    final tick = (t * 15).floor();
    final cycle = tick != _lastTick;
    _lastTick = tick;
    for (final die in _dice) {
      if (die.settled) continue;
      if (t >= die.settleAt) {
        die.settled = true;
        HapticFeedback.selectionClick();
      } else if (cycle) {
        die.tempValue = _cosmeticRng.nextInt(die.sides) + 1;
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.mediumImpact();
      setState(
          () => _total = _dice.fold<int>(0, (sum, die) => sum + die.value));
    }
  }

  void _changeCount(int sides, int delta) {
    if (_controller.isAnimating) return;
    if (delta > 0 && _poolSize >= _maxTotalDice) return;
    final next = (_counts[sides]! + delta).clamp(0, _maxPerType);
    if (next == _counts[sides]) return;
    setState(() {
      _counts[sides] = next;
      _dice = _idlePool();
      _total = null;
    });
  }

  void _clear() {
    if (_controller.isAnimating) return;
    setState(() {
      _counts.updateAll((_, __) => 0);
      _dice = [];
      _total = null;
    });
  }

  /// Unrolled dice shown as soon as the pool changes — each displays its
  /// highest face until rolled.
  List<_RolledDie> _idlePool() {
    return [
      for (final sides in _dieTypes)
        for (var c = 0; c < _counts[sides]!; c++)
          _RolledDie(
            sides: sides,
            value: sides,
            tempValue: sides,
            phase: 0,
            settleAt: 1,
            settled: true,
          ),
    ];
  }

  double get _dieSize {
    final n = _dice.length;
    if (n <= 6) return 72;
    if (n <= 12) return 56;
    return 44;
  }

  @override
  Widget build(BuildContext context) {
    final rolling = _controller.isAnimating;
    return ShakeGesture(
      onShake: _onShake,
      child: Scaffold(
        appBar: AppBar(title: const Text('Dice Roller')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _DiePoolSelector(
                counts: _counts,
                poolSize: _poolSize,
                enabled: !rolling,
                onChanged: _changeCount,
              ),
              Expanded(child: _buildDiceArea()),
              const SizedBox(height: 8),
              Text('TOTAL',
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 10, letterSpacing: 2, color: AppColors.sky400)),
              Text(_total?.toString() ?? '—',
                  key: const ValueKey('total-text'),
                  style: GoogleFonts.dmMono(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      color: _total == null
                          ? AppColors.ink100
                          : AppColors.ink600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _poolSize == 0 || rolling ? null : _roll,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('Roll'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest500,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  if (_poolSize > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: rolling ? null : _clear,
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiceArea() {
    if (_dice.isEmpty) {
      return Center(
        // scaleDown keeps the hint from overflowing on short screens.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino_outlined,
                  size: 72, color: AppColors.ink100),
              const SizedBox(height: 24),
              Text('Add dice above,\nthen roll or shake',
                  style: GoogleFonts.literata(
                      fontSize: 22, color: AppColors.ink300),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          key: const ValueKey('dice-area'),
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [for (final die in _dice) _buildDie(die)],
        ),
      ),
    );
  }

  Widget _buildDie(_RolledDie die) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        var dy = 0.0;
        var rot = 0.0;
        if (_controller.isAnimating && !die.settled) {
          final damp =
              1 - Curves.easeOut.transform((t / die.settleAt).clamp(0.0, 1.0));
          dy = sin(t * 30 + die.phase) * 4 * damp;
          rot = sin(t * 24 + die.phase) * 0.12 * damp;
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: rot,
            child: DieFace(
              sides: die.sides,
              value: die.settled ? die.value : die.tempValue,
              size: _dieSize,
            ),
          ),
        );
      },
    );
  }
}

// ── Pool selector ──────────────────────────────────────────────────────────────

class _DiePoolSelector extends StatelessWidget {
  final Map<int, int> counts;
  final int poolSize;
  final bool enabled;
  final void Function(int sides, int delta) onChanged;

  const _DiePoolSelector({
    required this.counts,
    required this.poolSize,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final sides in _dieTypes)
          Row(
            children: [
              DieFace(sides: sides, value: sides, size: 28),
              const SizedBox(width: 12),
              Text('d$sides',
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink600)),
              const Spacer(),
              IconButton(
                key: ValueKey('remove-d$sides'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.ink300,
                onPressed: enabled && counts[sides]! > 0
                    ? () => onChanged(sides, -1)
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text('${counts[sides]}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmMono(
                        fontSize: 16,
                        color: counts[sides]! > 0
                            ? AppColors.ink600
                            : AppColors.ink100)),
              ),
              IconButton(
                key: ValueKey('add-d$sides'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.sky400,
                onPressed: enabled &&
                        counts[sides]! < _maxPerType &&
                        poolSize < _maxTotalDice
                    ? () => onChanged(sides, 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

// ── Die face rendering ─────────────────────────────────────────────────────────

/// 2D rendering of a single die. Keep this API stable — a future 3D/physics
/// version should swap in behind the same `sides`/`value`/`size` contract.
class DieFace extends StatelessWidget {
  final int sides;
  final int value;
  final double size;

  const DieFace({
    super.key,
    required this.sides,
    required this.value,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DieShapePainter(sides: sides, value: value)),
    );
  }
}

class _DieShapePainter extends CustomPainter {
  final int sides;
  final int value;

  _DieShapePainter({required this.sides, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = AppColors.sky50;
    final stroke = Paint()
      ..color = AppColors.sky400
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * 0.035)
      ..strokeJoin = StrokeJoin.round;

    switch (sides) {
      case 6:
        final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.9, h * 0.9),
            Radius.circular(w * 0.18));
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, stroke);
        _paintPips(canvas, size);
        return;
      case 4:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.08)
          ..lineTo(w * 0.95, h * 0.88)
          ..lineTo(w * 0.05, h * 0.88)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        _paintValue(canvas, size, center: Offset(w * 0.5, h * 0.62));
      case 8:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.04)
          ..lineTo(w * 0.96, h * 0.5)
          ..lineTo(w * 0.5, h * 0.96)
          ..lineTo(w * 0.04, h * 0.5)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        _paintValue(canvas, size, center: Offset(w * 0.5, h * 0.5));
      case 10:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.04)
          ..lineTo(w * 0.94, h * 0.44)
          ..lineTo(w * 0.5, h * 0.96)
          ..lineTo(w * 0.06, h * 0.44)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        _paintValue(canvas, size, center: Offset(w * 0.5, h * 0.46));
      case 20:
      default:
        final center = Offset(w / 2, h / 2);
        final r = w * 0.46;
        final hex = Path();
        final tri = Path();
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * pi / 3;
          final p = center + Offset(cos(a), sin(a)) * r;
          i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
          if (i.isEven) {
            i == 0 ? tri.moveTo(p.dx, p.dy) : tri.lineTo(p.dx, p.dy);
          }
        }
        hex.close();
        tri.close();
        canvas.drawPath(hex, fill);
        // Faint inner triangle suggests the icosahedron's front facet.
        canvas.drawPath(
            tri,
            Paint()
              ..color = AppColors.sky100
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1, w * 0.02));
        canvas.drawPath(hex, stroke);
        _paintValue(canvas, size, center: center);
    }
  }

  void _paintPips(Canvas canvas, Size size) {
    final c = size.width / 2;
    final o = size.width * 0.21;
    const layouts = <int, List<Offset>>{
      1: [Offset(0, 0)],
      2: [Offset(-1, -1), Offset(1, 1)],
      3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
      4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
      5: [
        Offset(-1, -1),
        Offset(1, -1),
        Offset(0, 0),
        Offset(-1, 1),
        Offset(1, 1),
      ],
      6: [
        Offset(-1, -1),
        Offset(1, -1),
        Offset(-1, 0),
        Offset(1, 0),
        Offset(-1, 1),
        Offset(1, 1),
      ],
    };
    final pip = Paint()..color = AppColors.sky500;
    for (final unit in layouts[value.clamp(1, 6)]!) {
      canvas.drawCircle(
          Offset(c + unit.dx * o, c + unit.dy * o), size.width * 0.075, pip);
    }
  }

  void _paintValue(Canvas canvas, Size size, {required Offset center}) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: GoogleFonts.dmMono(
            fontSize: size.width * 0.32,
            fontWeight: FontWeight.w500,
            color: AppColors.sky600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_DieShapePainter oldDelegate) =>
      oldDelegate.sides != sides || oldDelegate.value != value;
}
