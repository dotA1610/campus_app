import 'package:flutter/material.dart';
import '../pages/admin_panel_page.dart';
import '../pages/hod_subject_requests_page.dart';

class FacultyShell extends StatefulWidget {
  final VoidCallback onLogout;

  // ✅ NEW: app-wide theme toggle control
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const FacultyShell({
    super.key,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<FacultyShell> createState() => _FacultyShellState();
}

class _FacultyShellState extends State<FacultyShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index = 0;

  void _go(int i, {bool closeDrawer = false}) {
    setState(() => index = i);
    if (closeDrawer) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dividerColor = theme.dividerColor;

    final pages = [
      const AdminPanelPage(),
      const HodSubjectRequestsPage(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,

          drawer: isWide ? null : Drawer(child: _buildNav(isDrawer: true)),

          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 270,
                    child: _buildNav(isDrawer: false),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        title: _titleForIndex(index),
                        onMenuTap: isWide
                            ? null
                            : () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: dividerColor),
                              ),
                              child: pages[index],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return "Leave Requests";
      case 1:
        return "Subject Requests";
      default:
        return "Faculty Dashboard";
    }
  }

  Widget _buildNav({required bool isDrawer}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dividerColor = theme.dividerColor;

    Widget navItem({
      required int i,
      required IconData icon,
      required String label,
    }) {
      final selected = index == i;
      final selectedBg = cs.primary.withOpacity(0.12);
      final selectedBorder = cs.primary.withOpacity(0.25);

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _go(i, closeDrawer: isDrawer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? selectedBorder : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? cs.onSurface : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? cs.onSurface : Colors.grey,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primary.withOpacity(0.18),
                    child: Icon(Icons.admin_panel_settings, size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Campusapp",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 10),
                    child: Text(
                      "Menu",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  navItem(i: 0, icon: Icons.event_note, label: "Leave Requests"),
                  const SizedBox(height: 8),
                  navItem(i: 1, icon: Icons.library_add, label: "Subject Requests"),
                ],
              ),
            ),
          ),

          // ✅ THEME TOGGLE
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Dark Mode",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: widget.isDarkMode,
                    onChanged: widget.onThemeChanged,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onLogout,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        "Logout",
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const _TopBar({
    required this.title,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: Icon(Icons.menu, color: cs.onSurface),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}