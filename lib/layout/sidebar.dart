import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final bool isAdmin;
  final Function(int) onSelect;
  final VoidCallback onLogout;

  const Sidebar(
      {super.key,
      required this.isAdmin,
      required this.onSelect,
      required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Menu",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
                title: const Text("Dashboard"),
                onTap: () => onSelect(0)),
            if (!isAdmin)
              ListTile(
                  title: const Text("Apply Leave"),
                  onTap: () => onSelect(1)),
            if (!isAdmin)
              ListTile(
                  title: const Text("Applications"),
                  onTap: () => onSelect(2)),
            if (isAdmin)
              ListTile(
                  title: const Text("Admin Panel"),
                  onTap: () => onSelect(1)),
            const Spacer(),
            ListTile(
              title: const Text("Logout"),
              onTap: onLogout,
            )
          ],
        ),
      ),
    );
  }
}
