import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../library/widgets/add_game_sheet.dart';

/// Global expandable quick actions button. Shown on every shell
/// tab except Dashboard, which already surfaces these as a labeled row.
class QuickActionsSpeedDial extends StatefulWidget {
  const QuickActionsSpeedDial({super.key});

  @override
  State<QuickActionsSpeedDial> createState() => _QuickActionsSpeedDialState();
}

class _QuickActionsSpeedDialState extends State<QuickActionsSpeedDial> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);
  void _close() => setState(() => _open = false);

  void _run(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_open,
            child: AnimatedOpacity(
              opacity: _open ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: GestureDetector(
                onTap: _close,
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.bottomCenter,
                  heightFactor: _open ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _open ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MiniAction(
                          icon: Icons.shuffle,
                          label: 'Game Picker',
                          onTap: () =>
                              _run(() => context.go('/game-nite/chooser')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.people_outline,
                          label: 'First Player',
                          onTap: () => _run(
                              () => context.go('/game-nite/first-player')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.timer_outlined,
                          label: 'Turn Timer',
                          onTap: () =>
                              _run(() => context.go('/game-nite/turn-timer')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.add_circle_outline,
                          label: 'Add Game',
                          onTap: () => _run(() => showAddGameSheet(context)),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.favorite_border,
                          label: 'Add to Wishlist',
                          onTap: () => _run(() => showAddGameSheet(context,
                              initialToWishlist: true)),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              FloatingActionButton(
                heroTag: 'quick-actions-dial-toggle',
                backgroundColor: AppColors.clay400,
                onPressed: _toggle,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    _open ? Icons.close : Icons.bolt,
                    key: ValueKey(_open),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A speed-dial action: a visible text label pill beside a small FAB. The
/// whole row is one tap target (min 48pt tall) and one semantics node.
class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.parchment50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.parchment200),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: Text(label,
                    style: AppTextStyles.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.ink500)),
              ),
              const SizedBox(width: 10),
              // Decorative: taps are handled by the row's InkWell.
              IgnorePointer(
                child: FloatingActionButton.small(
                  heroTag: 'quick-action-$label',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.clay400,
                  elevation: 2,
                  onPressed: () {},
                  child: Icon(icon),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
