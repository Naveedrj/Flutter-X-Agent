import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/adversarial_debate.dart';
import '../../models/llm_provider.dart';
import '../../providers/adversarial_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../app_theme.dart';

class SettingsDialog extends StatefulWidget {
  final int initialTabIndex;

  const SettingsDialog({super.key, this.initialTabIndex = 0});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Single Agent State
  late TextEditingController _apiKeyController;
  late TextEditingController _customModelController;
  late LlmProviderType _selectedProvider;
  late String _selectedModel;
  late double _temperature;
  bool _obscureKey = true;

  // Adversarial Arena State
  late LlmProviderType _blueProvider;
  late String _selectedBlueModel;
  late TextEditingController _blueCustomModelController;
  late TextEditingController _blueKeyController;
  bool _obscureBlueKey = true;

  late LlmProviderType _redProvider;
  late String _selectedRedModel;
  late TextEditingController _redCustomModelController;
  late TextEditingController _redKeyController;
  bool _obscureRedKey = true;

  late int _maxRounds;
  late AdversarialAttackFocus _focus;
  late double _advTemperature;

  final ScrollController _tab1Scroll = ScrollController();
  final ScrollController _tab2Scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final advProvider = Provider.of<AdversarialProvider>(context, listen: false);
    final cfg = advProvider.config;

    // Single Agent Init
    _selectedProvider = settings.activeProvider;
    _apiKeyController = TextEditingController(
      text: settings.apiKey == StorageService.defaultApiKeyPlaceholder ? '' : settings.apiKey,
    );
    _selectedModel = settings.model;
    _customModelController = TextEditingController(text: settings.model);
    _temperature = settings.temperature;

    // Adversarial Blue Init
    _blueProvider = cfg.blueProvider;
    _selectedBlueModel = cfg.blueModel.isNotEmpty ? cfg.blueModel : settings.model;
    _blueCustomModelController = TextEditingController(text: _selectedBlueModel);
    _blueKeyController = TextEditingController(
      text: cfg.blueApiKey.isNotEmpty
          ? cfg.blueApiKey
          : (settings.apiKey == StorageService.defaultApiKeyPlaceholder ? '' : settings.apiKey),
    );

    // Adversarial Red Init
    _redProvider = cfg.redProvider;
    _selectedRedModel = cfg.redModel.isNotEmpty ? cfg.redModel : _getDefaultModelForProvider(_redProvider);
    _redCustomModelController = TextEditingController(text: _selectedRedModel);
    _redKeyController = TextEditingController(
      text: cfg.redApiKey.isNotEmpty
          ? cfg.redApiKey
          : (settings.storageService.getApiKey(provider: _redProvider) == StorageService.defaultApiKeyPlaceholder
              ? ''
              : settings.storageService.getApiKey(provider: _redProvider)),
    );

    _maxRounds = cfg.maxRounds;
    _focus = cfg.focus;
    _advTemperature = cfg.temperature;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyController.dispose();
    _customModelController.dispose();
    _blueCustomModelController.dispose();
    _blueKeyController.dispose();
    _redCustomModelController.dispose();
    _redKeyController.dispose();
    _tab1Scroll.dispose();
    _tab2Scroll.dispose();
    super.dispose();
  }

  List<LlmModelInfo> _getUsableModelsForProvider(LlmProviderType p, SettingsProvider settings) {
    final live = settings.availableModels.where((m) => m.provider == p).toList();
    if (live.isNotEmpty) return live;
    return LlmProviderUtils.defaultModels.where((m) => m.provider == p).toList();
  }

  String _getDefaultModelForProvider(LlmProviderType p) {
    switch (p) {
      case LlmProviderType.gemini:
        return 'gemini-3.8-flash';
      case LlmProviderType.anthropic:
        return 'claude-3-5-sonnet-20241022';
      case LlmProviderType.groq:
        return 'qwen-2.5-coder-32b';
      case LlmProviderType.openrouter:
        return 'qwen/qwen-2.5-coder-32b-instruct:free';
      case LlmProviderType.ollama:
        return 'qwen2.5-coder:7b';
    }
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

  Future<void> _saveAllSettings() async {
    final settings = context.read<SettingsProvider>();
    final advProvider = context.read<AdversarialProvider>();

    // 1. Save Single Agent Settings
    final customSingle = _customModelController.text.trim();
    final effectiveSingleModel = customSingle.isNotEmpty ? customSingle : _selectedModel;
    final keyToSave = _apiKeyController.text.trim().isEmpty
        ? StorageService.defaultApiKeyPlaceholder
        : _apiKeyController.text.trim();

    await settings.setActiveProvider(_selectedProvider);
    await settings.setApiKey(keyToSave, provider: _selectedProvider);
    await settings.setModel(effectiveSingleModel);
    await settings.setTemperature(_temperature);

    // 2. Save Adversarial Arena Settings
    final customBlue = _blueCustomModelController.text.trim();
    final effectiveBlueModel = customBlue.isNotEmpty ? customBlue : _selectedBlueModel;

    final customRed = _redCustomModelController.text.trim();
    final effectiveRedModel = customRed.isNotEmpty ? customRed : _selectedRedModel;

    final blueKeyToSave = _blueKeyController.text.trim().isNotEmpty ? _blueKeyController.text.trim() : keyToSave;
    final redKeyToSave = _redKeyController.text.trim();

    if (redKeyToSave.isNotEmpty) {
      await settings.storageService.setApiKey(redKeyToSave, provider: _redProvider);
    }
    if (blueKeyToSave.isNotEmpty && blueKeyToSave != StorageService.defaultApiKeyPlaceholder) {
      await settings.storageService.setApiKey(blueKeyToSave, provider: _blueProvider);
    }

    final newAdvConfig = AdversarialConfig(
      blueProvider: _blueProvider,
      blueModel: effectiveBlueModel,
      blueApiKey: blueKeyToSave,
      redProvider: _redProvider,
      redModel: effectiveRedModel,
      redApiKey: redKeyToSave,
      maxRounds: _maxRounds,
      focus: _focus,
      temperature: _advTemperature,
    );
    advProvider.updateConfig(newAdvConfig);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenHeight * 0.90,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Model & Arena Configuration',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryLight,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.smart_toy_outlined, size: 16),
                      text: 'Single Agent Model',
                    ),
                    Tab(
                      icon: Icon(Icons.shield, size: 16),
                      text: 'Adversarial Duel Arena',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tab Views
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Single Agent Model Configuration
                    _buildSingleAgentTab(settings),

                    // TAB 2: Adversarial Arena Duel Configuration
                    _buildAdversarialTab(settings),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save & Apply Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _saveAllSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleAgentTab(SettingsProvider settings) {
    final currentModels = _getUsableModelsForProvider(_selectedProvider, settings);

    return Scrollbar(
      controller: _tab1Scroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tab1Scroll,
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT PROVIDER',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: LlmProviderType.values.map((p) {
                final isSelected = p == _selectedProvider;
                final isFree = p == LlmProviderType.groq || p == LlmProviderType.ollama;

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
                      if (isFree) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('FREE', style: TextStyle(fontSize: 8.5, color: AppTheme.success, fontWeight: FontWeight.bold)),
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

                        final modelsForP = _getUsableModelsForProvider(p, settings);
                        if (!modelsForP.any((m) => m.id == _selectedModel)) {
                          _selectedModel = modelsForP.isNotEmpty ? modelsForP.first.id : _getDefaultModelForProvider(p);
                          _customModelController.text = _selectedModel;
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // API Key Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${LlmProviderUtils.getProviderName(_selectedProvider)} API Key / Host URL',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                Text(
                  _selectedProvider == LlmProviderType.groq
                      ? 'Free: console.groq.com'
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

            // Model Dropdown & Custom Model Input
            Row(
              children: [
                const Text(
                  'MODEL SELECTION',
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
                              child: const Text('FREE', style: TextStyle(fontSize: 9, color: AppTheme.success, fontWeight: FontWeight.bold)),
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
                    if (val != null) {
                      setState(() {
                        _selectedModel = val;
                        _customModelController.text = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Custom Model Text Input
            TextField(
              controller: _customModelController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Or Type Custom Model Identifier',
                labelStyle: const TextStyle(fontSize: 11, color: Colors.white60),
                hintText: 'e.g. qwen2.5-coder:32b, deepseek-r1:14b, claude-3-7-sonnet',
                hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25)),
                prefixIcon: const Icon(Icons.edit_note, size: 16, color: AppTheme.accentCyan),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() => _selectedModel = val.trim());
                }
              },
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
          ],
        ),
      ),
    );
  }

  Widget _buildAdversarialTab(SettingsProvider settings) {
    final blueModels = _getUsableModelsForProvider(_blueProvider, settings);
    final redModels = _getUsableModelsForProvider(_redProvider, settings);

    return Scrollbar(
      controller: _tab2Scroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tab2Scroll,
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔵 BLUE TEAM (Builder)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, size: 15, color: AppTheme.accentCyan),
                      SizedBox(width: 6),
                      Text(
                        '🔵 Blue Team (Developer / Architect)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Blue Provider Dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LlmProviderType>(
                              value: _blueProvider,
                              isExpanded: true,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(fontSize: 11.5, color: Colors.white),
                              items: LlmProviderType.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(LlmProviderUtils.getProviderName(p)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _blueProvider = val;
                                    final list = _getUsableModelsForProvider(val, settings);
                                    _selectedBlueModel = list.isNotEmpty ? list.first.id : _getDefaultModelForProvider(val);
                                    _blueCustomModelController.text = _selectedBlueModel;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Blue Model Dropdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: blueModels.any((m) => m.id == _selectedBlueModel)
                                  ? _selectedBlueModel
                                  : (blueModels.isNotEmpty ? blueModels.first.id : null),
                              isExpanded: true,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Colors.white),
                              items: blueModels.map((m) {
                                return DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedBlueModel = val;
                                    _blueCustomModelController.text = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Blue Custom Model Name
                  TextField(
                    controller: _blueCustomModelController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Blue Model Custom Name (Optional)',
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white60),
                      hintText: 'e.g. qwen2.5-coder:32b or custom identifier',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25)),
                      prefixIcon: const Icon(Icons.edit_note, size: 15, color: AppTheme.accentCyan),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) setState(() => _selectedBlueModel = val.trim());
                    },
                  ),
                  const SizedBox(height: 8),
                  // Blue API Key
                  TextField(
                    controller: _blueKeyController,
                    obscureText: _obscureBlueKey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Blue Team API Key / Host URL',
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white60),
                      hintText: 'Leave empty to use global default key',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25)),
                      prefixIcon: const Icon(Icons.key, size: 15, color: AppTheme.accentCyan),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureBlueKey ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white54),
                        onPressed: () => setState(() => _obscureBlueKey = !_obscureBlueKey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 🔴 RED TEAM (Security Hacker / Stress-Tester)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF200F15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF881337)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security, size: 15, color: Color(0xFFFB7185)),
                      SizedBox(width: 6),
                      Text(
                        '🔴 Red Team (Security Hacker / Adversary)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFB7185)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Red Provider Dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E101D),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF881337)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LlmProviderType>(
                              value: _redProvider,
                              isExpanded: true,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(fontSize: 11.5, color: Colors.white),
                              items: LlmProviderType.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(LlmProviderUtils.getProviderName(p)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _redProvider = val;
                                    final list = _getUsableModelsForProvider(val, settings);
                                    _selectedRedModel = list.isNotEmpty ? list.first.id : _getDefaultModelForProvider(val);
                                    _redCustomModelController.text = _selectedRedModel;
                                    final savedRedKey = settings.storageService.getApiKey(provider: val);
                                    if (savedRedKey != StorageService.defaultApiKeyPlaceholder && savedRedKey.isNotEmpty) {
                                      _redKeyController.text = savedRedKey;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Red Model Dropdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E101D),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF881337)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: redModels.any((m) => m.id == _selectedRedModel)
                                  ? _selectedRedModel
                                  : (redModels.isNotEmpty ? redModels.first.id : null),
                              isExpanded: true,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Colors.white),
                              items: redModels.map((m) {
                                return DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRedModel = val;
                                    _redCustomModelController.text = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Red Custom Model Name
                  TextField(
                    controller: _redCustomModelController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Red Model Custom Name (Optional)',
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white60),
                      hintText: 'e.g. llama3.3:70b or custom identifier',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25)),
                      prefixIcon: const Icon(Icons.edit_note, size: 15, color: Color(0xFFFB7185)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) setState(() => _selectedRedModel = val.trim());
                    },
                  ),
                  const SizedBox(height: 8),
                  // Red API Key
                  TextField(
                    controller: _redKeyController,
                    obscureText: _obscureRedKey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Red Team API Key / Host URL',
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white60),
                      hintText: 'Enter API key or Ollama host for Red Team',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25)),
                      prefixIcon: const Icon(Icons.key, size: 15, color: Color(0xFFFB7185)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureRedKey ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white54),
                        onPressed: () => setState(() => _obscureRedKey = !_obscureRedKey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // DUEL PARAMETERS
            const Text(
              'DUEL PARAMETERS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 8),

            // Attack Focus
            const Text('Attack & Stress-Test Focus:', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: AdversarialAttackFocus.values.map((f) {
                final isSel = f == _focus;
                return ChoiceChip(
                  label: Text(f.label, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : Colors.white70)),
                  selected: isSel,
                  selectedColor: AppTheme.primary,
                  backgroundColor: const Color(0xFF131D30),
                  onSelected: (_) => setState(() => _focus = f),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Max Rounds Slider
            Row(
              children: [
                Text(
                  'Max Duel Rounds: $_maxRounds ${_maxRounds == 1 ? 'Round' : 'Rounds'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const Spacer(),
                const Text('(Stops early on consensus)', style: TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
            Slider(
              value: _maxRounds.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_maxRounds Rounds',
              activeColor: AppTheme.primaryLight,
              onChanged: (val) => setState(() => _maxRounds = val.toInt()),
            ),
          ],
        ),
      ),
    );
  }
}
