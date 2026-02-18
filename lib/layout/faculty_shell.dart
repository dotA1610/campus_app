import 'package:flutter/material.dart';
import '../pages/admin_panel_page.dart';
import '../pages/hod_subject_requests_page.dart';

class FacultyShell extends StatefulWidget {
  final VoidCallback onLogout;

  const FacultyShell({super.key, required this.onLogout});

  @override
  State<FacultyShell> createState() => _FacultyShellState();
}

class _FacultyShellState extends State<FacultyShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int index = 0; // 0 = Leave Requests, 1 = Subject Requests

  // --------- LOCKED UI THEME ----------
  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  void _go(int i, {bool closeDrawer = false}) {
    setState(() => index = i);
    if (closeDrawer) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminPanelPage(), // Leave requests
      const HodSubjectRequestsPage(), // Subject add/drop requests
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bg,

          // Drawer only for small screens
          drawer: isWide ? null : Drawer(child: _buildNav(isDrawer: true)),

          body: SafeArea(
            child: Row(
              children: [
                // LEFT SIDEBAR (web)
                if (isWide)
                  SizedBox(
                    width: 270,
                    child: _buildNav(isDrawer: false),
                  ),

                // MAIN AREA
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
                                color: _card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _border),
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
    Widget navItem({
      required int i,
      required IconData icon,
      required String label,
    }) {
      final selected = index == i;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _go(i, closeDrawer: isDrawer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1C1C24) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _border : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: _card2,
      child: Column(
        children: [
          const SizedBox(height: 14),

          // Brand header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF2A2A34),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Campusapp",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Menu
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

          // Logout
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
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
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.white,
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

  static const _border = Color(0xFF24242D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0F),
        border: Border(
          bottom: BorderSide(color: _border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
