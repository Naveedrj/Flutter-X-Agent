import 'package:flutter/material.dart';
import 'settings_dialog.dart';

class AdversarialConfigDialog extends StatelessWidget {
  const AdversarialConfigDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsDialog(initialTabIndex: 1);
  }
}
