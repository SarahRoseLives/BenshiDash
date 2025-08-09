import 'package:flutter/material.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';

// --- Theme Notifier ---
/// A simple state manager for the app's theme.
///
/// NOTE: This is a simplified in-memory state manager. For the theme choice
/// to persist across app restarts, a library like 'shared_preferences'
/// would be required to save and load the user's preference.
class ThemeNotifier extends ChangeNotifier {
  // Default to dark mode as per the original UI design.
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Sets the new theme and notifies any listening widgets to rebuild.
  void setTheme(ThemeMode themeMode) {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      notifyListeners(); // This is what triggers the UI update.
    }
  }
}

/// A global instance of the theme notifier, accessible throughout the app.
final ThemeNotifier themeNotifier = ThemeNotifier();

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use an AnimatedBuilder to ensure the Switch updates when the theme changes.
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return MainLayout(
          radio: radio,
          battery: battery,
          gps: gps,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Appearance',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              Card(
                color: theme.cardTheme.color,
                child: SwitchListTile(
                  title: const Text('Enable Dark Mode'),
                  subtitle: Text(
                    'Switch between light and dark themes.',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                  ),
                  value: themeNotifier.isDarkMode,
                  onChanged: (isDark) {
                    // Calling this method triggers the update across the app.
                    themeNotifier
                        .setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
                  },
                  secondary: Icon(
                    themeNotifier.isDarkMode
                        ? Icons.nightlight_round
                        : Icons.wb_sunny,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              // Add other settings categories and items here...
            ],
          ),
        );
      },
    );
  }
}