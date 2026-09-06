import 'package:flutter/material.dart';

import '../data/remote/organisation_profile_repository.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({
    super.key,
    required this.mainPage,
    required this.profilePage,
    this.scannerPage,
  });

  final Widget mainPage;
  final Widget profilePage;
  final Widget? scannerPage;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: OrganisationProfileRepository.revision,
    builder: (context, profileRevision, _) => Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          KeyedSubtree(
            key: ValueKey('staff-main-$profileRevision'),
            child: widget.mainPage,
          ),
          KeyedSubtree(
            key: ValueKey('staff-profile-$profileRevision'),
            child: widget.profilePage,
          ),
        ],
      ),
      bottomNavigationBar: _CurvedRoleNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) => setState(() => selectedIndex = index),
        onScan: widget.scannerPage == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => widget.scannerPage!),
              ),
      ),
    ),
  );
}

class _CurvedRoleNavigation extends StatelessWidget {
  const _CurvedRoleNavigation({
    required this.selectedIndex,
    required this.onSelected,
    this.onScan,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
        decoration: BoxDecoration(
          color: theme.navigationBarTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _RoleDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Main',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
            ),
            if (onScan != null)
              Semantics(
                label: 'QR attendance scanner',
                button: true,
                child: InkWell(
                  onTap: onScan,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 54,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .28),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _RoleDestination(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDestination extends StatelessWidget {
  const _RoleDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: .15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? accent : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : null,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
