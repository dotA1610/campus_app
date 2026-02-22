// lib/app/app_keyboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide keyboard behavior:
/// - Ensures focus traversal is enabled (Tab/Shift+Tab)
/// - Adds common shortcuts (Esc to close dialogs/routes)
/// - Provides a place to add more global shortcuts later
class AppKeyboard extends StatelessWidget {
  final Widget child;

  /// Optional: per-route search focus hook.
  /// If the current page provides a handler via InheritedWidget / callback,
  /// you can wire Ctrl+F to it. For now we keep it null-safe.
  final VoidCallback? onGlobalSearch;

  const AppKeyboard({
    super.key,
    required this.child,
    this.onGlobalSearch,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Close dialogs / back
          LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),

          // Optional: global search (Ctrl+F)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
              const _SearchIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _EscapeIntent: CallbackAction<_EscapeIntent>(
              onInvoke: (intent) {
                // Works for dialogs & pages
                Navigator.of(context).maybePop();
                return null;
              },
            ),
            _SearchIntent: CallbackAction<_SearchIntent>(
              onInvoke: (intent) {
                onGlobalSearch?.call();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            canRequestFocus: true,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}