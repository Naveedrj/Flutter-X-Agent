import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _apiKeyController;
  late String _selectedModel;
  late double _temperature;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _apiKeyController = TextEditingController(
      text: settings.apiKey == StorageService.defaultApiKeyPlaceholder ? '' : settings.apiKey,
    );
    _selectedModel = settings.model;
    _temperature = settings.temperature;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Agent & Gemini Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // API Key field
            const Text(
              'Gemini API Key',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter your Gemini API key (e.g. AIzaSy...)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    if (_apiKeyController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                        onPressed: () => setState(() => _apiKeyController.clear()),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Leave blank to keep placeholder or paste your API key from Google AI Studio.',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
            ),

            const SizedBox(height: 18),

            // Model Selection
            const Text(
              'Gemini Model',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131D30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: SettingsProvider.availableModels.contains(_selectedModel)
                      ? _selectedModel
                      : SettingsProvider.availableModels.first,
                  isExpanded: true,
                  dropdownColor: AppTheme.darkSurface,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  items: SettingsProvider.availableModels.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(m, style: const TextStyle(fontFamily: 'monospace')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedModel = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Temperature Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Temperature (Creativity)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                Text(
                  _temperature.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppTheme.primaryLight),
                ),
              ],
            ),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: AppTheme.primary,
              inactiveColor: AppTheme.darkBorder,
              onChanged: (val) => setState(() => _temperature = val),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final keyToSave = _apiKeyController.text.trim().isEmpty
                        ? StorageService.defaultApiKeyPlaceholder
                        : _apiKeyController.text.trim();
                    await settings.setApiKey(keyToSave);
                    await settings.setModel(_selectedModel);
                    await settings.setTemperature(_temperature);
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
