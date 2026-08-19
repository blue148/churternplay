import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../library/widgets/add_game_sheet.dart';

/// Global, icon-only expandable quick actions button. Shown on every shell
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
                          tooltip: 'Game Picker',
                          onTap: () =>
                              _run(() => context.go('/game-nite/chooser')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.people_outline,
                          tooltip: 'First Player',
                          onTap: () => _run(
                              () => context.go('/game-nite/first-player')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.timer_outlined,
                          tooltip: 'Turn Timer',
                          onTap: () =>
                              _run(() => context.go('/game-nite/turn-timer')),
                        ),
                        const SizedBox(height: 10),
                        _MiniAction(
                          icon: Icons.add_circle_outline,
                          tooltip: 'Add Game',
                          onTap: () => _run(() => showAddGameSheet(context)),
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

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.small(
        heroTag: 'quick-action-$tooltip',
        backgroundColor: Colors.white,
        foregroundColor: AppColors.clay400,
        elevation: 2,
        onPressed: onTap,
        child: Icon(icon),
      ),
    );
  }
}
