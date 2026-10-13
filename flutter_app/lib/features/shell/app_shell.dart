import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/library_provider.dart';
import 'widgets/quick_actions_speed_dial.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Dashboard (index 0) already shows these as a labeled row, so the
    // icon-only global dial only appears once the user has navigated away.
    final showQuickActionsDial = navigationShell.currentIndex != 0;

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          if (showQuickActionsDial)
            const Positioned.fill(child: QuickActionsSpeedDial()),
        ],
      ),
      bottomNavigationBar: _AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// One entry in a bottom-nav item's long-press section menu.
class _SectionMenuOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SectionMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Custom bottom nav bar (rather than the stock [NavigationBar]) so each
/// item can support both a tap (switch tab) and a long-press (open a menu
/// jumping straight to one of that tab's sections).
class _AppBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AppBottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.ink50, width: 1)),
        ),
        child: Row(
          children: [
            _NavBarItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: 'Dashboard',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavBarItem(
              icon: Icons.casino_outlined,
              selectedIcon: Icons.casino,
              label: 'Game Nite',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              onLongPress: () => _showSectionMenu(
                context,
                title: 'Game Nite',
                options: [
                  _SectionMenuOption(
                    icon: Icons.shuffle,
                    label: 'Game Picker',
                    onTap: () => context.push('/game-nite/chooser'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.people_outline,
                    label: 'First Player',
                    onTap: () => context.push('/game-nite/first-player'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.timer_outlined,
                    label: 'Turn Timer',
                    onTap: () => context.push('/game-nite/turn-timer'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.hourglass_bottom_outlined,
                    label: 'Game Timer',
                    onTap: () => context.push('/game-nite/game-timer'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.casino_outlined,
                    label: 'Dice Roller',
                    onTap: () => context.push('/game-nite/dice-roller'),
                  ),
                ],
              ),
            ),
            _NavBarItem(
              icon: Icons.collections_bookmark_outlined,
              selectedIcon: Icons.collections_bookmark,
              label: 'My Games',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
              onLongPress: () => _showSectionMenu(
                context,
                title: 'My Games',
                options: [
                  _SectionMenuOption(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'My Library',
                    onTap: () => _goToLibraryTab(context, ref, 0),
                  ),
                  _SectionMenuOption(
                    icon: Icons.list_alt_outlined,
                    label: 'Wishlist',
                    onTap: () => _goToLibraryTab(context, ref, 1),
                  ),
                  _SectionMenuOption(
                    icon: Icons.people_outline,
                    label: "Friend's Games",
                    onTap: () => _goToLibraryTab(context, ref, 2),
                  ),
                ],
              ),
            ),
            _NavBarItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
              onLongPress: () => _showSectionMenu(
                context,
                title: 'Profile',
                options: [
                  _SectionMenuOption(
                    icon: Icons.people_outline,
                    label: 'Friends',
                    onTap: () => context.push('/profile/friends'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.badge_outlined,
                    label: 'Profile Details',
                    onTap: () => context.push('/profile/details'),
                  ),
                  _SectionMenuOption(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push('/profile/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToLibraryTab(BuildContext context, WidgetRef ref, int tabIndex) {
    ref.read(pendingLibraryTabProvider.notifier).set(tabIndex);
    context.go('/library');
  }

  Future<void> _showSectionMenu(
    BuildContext context, {
    required String title,
    required List<_SectionMenuOption> options,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: GoogleFonts.literata(
                      fontSize: 18, color: AppColors.ink600),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(option.icon, color: AppColors.ink500, size: 22),
                title: Text(
                  option.label,
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 15, color: AppColors.ink500),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  option.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest500 : AppColors.ink200;
    final labelColor = selected ? AppColors.forest500 : AppColors.ink300;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.forest100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    Icon(selected ? selectedIcon : icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
