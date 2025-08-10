import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';
// If you want clickable URLs, also add:
// import 'package:url_launcher/url_launcher.dart';

import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _showPackagesDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.code, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Text("Packages & Credits"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This app is built using these open-source packages and libraries:",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _pkg(
                theme,
                name: "Flutter",
                url: "https://flutter.dev/",
                description: "The UI toolkit for building beautiful multi-platform apps.",
              ),
              _pkg(
                theme,
                name: "benshi_flutter (directly integrated)",
                url: "https://github.com/sarahroselives/benshi_flutter",
                description: "A Dart/Flutter port of the Benshi protocol for radio communication, based on Benlink.",
              ),
              _pkg(
                theme,
                name: "Material Icons",
                url: "https://fonts.google.com/icons",
                description: "Google's official icon library.",
              ),
              _pkg(
                theme,
                name: "Other Dart/Flutter packages",
                url: "https://pub.dev/",
                description: "See the pubspec.yaml for additional dependencies.",
              ),
              const SizedBox(height: 20),
              Text(
                "Special thanks to:",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "• Kyle Husmann — Benshi protocol reverse engineering, creator of Benlink\n"
                "• Flutter, Dart, and open-source contributors everywhere",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  static Widget _pkg(
    ThemeData theme, {
    required String name,
    required String url,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          children: [
            WidgetSpan(
              child: Icon(Icons.check_circle_outline, color: theme.colorScheme.secondary, size: 18),
              alignment: PlaceholderAlignment.middle,
            ),
            const WidgetSpan(child: SizedBox(width: 6)),
            TextSpan(
              text: name,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // For real apps: use url_launcher to open URL
                  // launchUrl(Uri.parse(url));
                },
            ),
            const TextSpan(text: "  "),
            TextSpan(
              text: description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen for connection status changes from the global notifier
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          // --- THIS IS THE CHANGE ---
          radioController: radioController,
          // --- END OF CHANGE ---
          radio: radio,
          battery: battery,
          gps: gps,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showPackagesDialog(context),
                    child: Icon(Icons.info_outline, size: 56, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'About This App',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "This application was created after staring at a car's dashboard and thinking about what it might be like if ham radio operators had their own car dashboard just for their radio.\n\n"
                    "Then it dawned on me that I had ported the benshi protocol from Benlink to Dart for Flutter apps like Benshi Commander.\n\n"
                    "Thus I decided to base the head unit on these radios due to their Bluetooth functionality and the new ability to create Android apps thanks to my Flutter port of the protocol.\n\n"
                    "Credits to Kyle Husmann for the original efforts to reverse engineer the benshi protocol and creating Benlink, which my Flutter port is based off of.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '— Created by SarahRose AD8NT/K8SDR',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text("Show Packages & Credits"),
                    onPressed: () => _showPackagesDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      textStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}