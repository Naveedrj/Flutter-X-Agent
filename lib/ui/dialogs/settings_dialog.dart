import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/llm_provider.dart';
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
  late LlmProviderType _selectedProvider;
  late String _selectedModel;
  late double _temperature;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _selectedProvider = settings.activeProvider;
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

  void _onKeyChanged(String key) {
    if (key.trim().isNotEmpty) {
      final detected = LlmProviderUtils.detectProviderFromKey(key);
      if (detected != _selectedProvider) {
        setState(() {
          _selectedProvider = detected;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentModels = settings.currentProviderModels;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'LLM Provider & Model Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Provider Selector Chips
              const Text(
                'SELECT LLM PROVIDER',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: LlmProviderType.values.map((p) {
                  final isSelected = p == _selectedProvider;
                  final isFreeProvider = p == LlmProviderType.groq || p == LlmProviderType.ollama;

                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LlmProviderUtils.getProviderName(p),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        if (isFreeProvider) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('FREE', style: TextStyle(fontSize: 9, color: AppTheme.success, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: const Color(0xFF131D30),
                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.darkBorder),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedProvider = p;
                          final savedKey = settings.storageService.getApiKey(provider: p);
                          _apiKeyController.text = savedKey == StorageService.defaultApiKeyPlaceholder ? '' : savedKey;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // API Key input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${LlmProviderUtils.getProviderName(_selectedProvider)} API Key',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  Text(
                    _selectedProvider == LlmProviderType.groq
                        ? 'Instant Free: console.groq.com'
                        : _selectedProvider == LlmProviderType.gemini
                            ? 'aistudio.google.com'
                            : _selectedProvider == LlmProviderType.ollama
                                ? 'e.g. http://localhost:11434'
                                : 'Auto-detected on paste',
                    style: const TextStyle(fontSize: 10, color: AppTheme.primaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: _selectedProvider == LlmProviderType.groq
                      ? 'Enter Groq key (e.g. gsk_...)'
                      : _selectedProvider == LlmProviderType.anthropic
                          ? 'Enter Anthropic key (e.g. sk-ant-...)'
                          : _selectedProvider == LlmProviderType.gemini
                              ? 'Enter Gemini key (e.g. AIzaSy...)'
                              : _selectedProvider == LlmProviderType.ollama
                                  ? 'http://localhost:11434'
                                  : 'Enter API key (auto-detected)...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                onChanged: _onKeyChanged,
              ),

              const SizedBox(height: 16),

              // Working Model Selector & Fetch Button
              Row(
                children: [
                  const Text(
                    'SELECT MODEL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(0, 24),
                      foregroundColor: AppTheme.accentCyan,
                    ),
                    icon: settings.isFetchingModels
                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentCyan))
                        : const Icon(Icons.refresh, size: 13),
                    label: Text(settings.isFetchingModels ? 'Fetching...' : 'Fetch Live Models', style: const TextStyle(fontSize: 11)),
                    onPressed: settings.isFetchingModels
                        ? null
                        : () async {
                            final key = _apiKeyController.text.trim();
                            if (key.isNotEmpty) {
                              await settings.setApiKey(key, provider: _selectedProvider);
                            }
                            await settings.fetchLiveModels();
                          },
                  ),
                ],
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
                    value: currentModels.any((m) => m.id == _selectedModel)
                        ? _selectedModel
                        : (currentModels.isNotEmpty ? currentModels.first.id : null),
                    isExpanded: true,
                    dropdownColor: AppTheme.darkSurface,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                    items: currentModels.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Row(
                          children: [
                            if (m.isFree) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('FREE', style: TextStyle(fontSize: 9.5, color: AppTheme.success, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                m.displayName,
                                style: const TextStyle(fontFamily: 'monospace'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedModel = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Temperature Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Creativity (Temperature)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  Text(
                    _temperature.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.primaryLight),
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

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      final keyToSave = _apiKeyController.text.trim().isEmpty
                          ? StorageService.defaultApiKeyPlaceholder
                          : _apiKeyController.text.trim();
                      await settings.setActiveProvider(_selectedProvider);
                      await settings.setApiKey(keyToSave, provider: _selectedProvider);
                      await settings.setModel(_selectedModel);
                      await settings.setTemperature(_temperature);
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Save Provider & Model'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
