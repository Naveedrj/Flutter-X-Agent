import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/adversarial_debate.dart';
import '../../models/llm_provider.dart';
import '../../providers/adversarial_provider.dart';
import '../../providers/settings_provider.dart';
import '../app_theme.dart';

class AdversarialConfigDialog extends StatefulWidget {
  const AdversarialConfigDialog({super.key});

  @override
  State<AdversarialConfigDialog> createState() => _AdversarialConfigDialogState();
}

class _AdversarialConfigDialogState extends State<AdversarialConfigDialog> {
  late LlmProviderType _redProvider;
  late String _selectedRedModel;
  late TextEditingController _redKeyController;

  late int _maxRounds;
  late AdversarialAttackFocus _focus;
  late double _temperature;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final advProvider = Provider.of<AdversarialProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final cfg = advProvider.config;

    _redProvider = cfg.redProvider;
    
    final usableModels = _getUsableModelsForProvider(_redProvider);
    if (usableModels.any((m) => m.id == cfg.redModel)) {
      _selectedRedModel = cfg.redModel;
    } else if (usableModels.any((m) => m.id == settings.model)) {
      _selectedRedModel = settings.model;
    } else {
      _selectedRedModel = _getDefaultModelForProvider(_redProvider);
    }

    _redKeyController = TextEditingController(text: cfg.redApiKey);
    _maxRounds = cfg.maxRounds;
    _focus = cfg.focus;
    _temperature = cfg.temperature;
  }

  @override
  void dispose() {
    _redKeyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final advProvider = context.read<AdversarialProvider>();
    final settings = context.read<SettingsProvider>();

    final newConfig = AdversarialConfig(
      blueProvider: settings.activeProvider,
      blueModel: settings.model,
      blueApiKey: settings.apiKey,
      redProvider: _redProvider,
      redModel: _selectedRedModel,
      redApiKey: _redKeyController.text.trim(),
      maxRounds: _maxRounds,
      focus: _focus,
      temperature: _temperature,
    );
    advProvider.updateConfig(newConfig);
    Navigator.of(context).pop();
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
          maxWidth: 640,
          maxHeight: screenHeight * 0.88,
        ),
        child: Container(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.security, color: AppTheme.accentCyan, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '⚔️ Adversarial Arena Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Scrollable Options
              Flexible(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔵 BLUE TEAM SECTION (Global Inherited)
                        _buildBlueTeamGlobalCard(settings),

                        const SizedBox(height: 16),

                        // 🔴 RED TEAM SECTION (Dropdown Model Selection)
                        _buildRedTeamSection(settings),

                        const SizedBox(height: 18),

                        // ⚙️ DUEL PARAMETERS
                        const Text(
                          'DUEL PARAMETERS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                        ),
                        const SizedBox(height: 8),

                        // Attack Focus Chips
                        const Text('Attack & Optimization Focus:', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                              'Max Debate Rounds: $_maxRounds ${_maxRounds == 1 ? 'Round' : 'Rounds'}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            const Spacer(),
                            const Text('(Stops early if consensus reached)', style: TextStyle(fontSize: 10, color: Colors.white38)),
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
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save Arena Config'),
                    onPressed: _saveAndClose,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlueTeamGlobalCard(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🔵 Blue Team (Developer / Architect)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 11, color: AppTheme.accentCyan),
                    SizedBox(width: 4),
                    Text(
                      'Global Active Model',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Writes initial code, designs systems, and patches vulnerabilities.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF08101E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${settings.activeProvider.displayName} • ${settings.model}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                Text(
                  settings.apiKey.isNotEmpty ? '🔑 Key Configured' : '⚠️ Missing Key',
                  style: TextStyle(
                    fontSize: 11,
                    color: settings.apiKey.isNotEmpty ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedTeamSection(SettingsProvider settings) {
    final usableModels = _getUsableModelsForProvider(_redProvider);
    
    // Ensure selected model belongs to current provider
    if (!usableModels.any((m) => m.id == _selectedRedModel)) {
      _selectedRedModel = usableModels.isNotEmpty ? usableModels.first.id : _getDefaultModelForProvider(_redProvider);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C131D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF881337)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔴 Red Team (Hacker / Security Critic)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF87171),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Attacks code, exposes security holes, race conditions, and performance flaws.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 10),

          // Provider selector
          const Text('Provider:', style: TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: LlmProviderType.values.map((p) {
              final isSel = p == _redProvider;
              final isFree = p == LlmProviderType.groq || p == LlmProviderType.ollama;
              return ChoiceChip(
                label: Text(
                  '${p.displayName}${isFree ? ' [FREE]' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.white : Colors.white70,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFFE11D48),
                backgroundColor: const Color(0xFF131D30),
                onSelected: (_) {
                  setState(() {
                    _redProvider = p;
                    final models = _getUsableModelsForProvider(p);
                    _selectedRedModel = models.isNotEmpty ? models.first.id : _getDefaultModelForProvider(p);
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Usable Models Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Hacker Model:', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRedModel,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1528),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF87171)),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    items: usableModels.map((modelInfo) {
                      return DropdownMenuItem<String>(
                        value: modelInfo.id,
                        child: Row(
                          children: [
                            Text(
                              modelInfo.displayName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            if (modelInfo.isFree)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRedModel = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Custom API Key / Host Override
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('API Key / Host (Optional Override):', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
              const SizedBox(height: 3),
              TextField(
                controller: _redKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _redProvider == settings.activeProvider
                      ? 'Reusing global key from Settings ⚙️ (leave blank or enter custom key)'
                      : 'Enter API key or host for ${_redProvider.displayName}',
                  hintStyle: const TextStyle(fontSize: 10.5, color: Colors.white30),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<LlmModelInfo> _getUsableModelsForProvider(LlmProviderType p) {
    switch (p) {
      case LlmProviderType.gemini:
        return const [
          LlmModelInfo(id: 'gemini-3.8-flash', displayName: 'Gemini 3.8 Flash (Latest)', provider: LlmProviderType.gemini, isFree: true),
          LlmModelInfo(id: 'gemini-2.0-flash', displayName: 'Gemini 2.0 Flash (Next-Gen)', provider: LlmProviderType.gemini, isFree: true),
          LlmModelInfo(id: 'gemini-1.5-flash', displayName: 'Gemini 1.5 Flash (Free Tier)', provider: LlmProviderType.gemini, isFree: true),
          LlmModelInfo(id: 'gemini-1.5-pro', displayName: 'Gemini 1.5 Pro (Deep Multi-file)', provider: LlmProviderType.gemini, isFree: false),
        ];
      case LlmProviderType.groq:
        return const [
          LlmModelInfo(id: 'qwen-2.5-coder-32b', displayName: 'Qwen 2.5 Coder 32B (Ultra Fast)', provider: LlmProviderType.groq, isFree: true),
          LlmModelInfo(id: 'llama-3.3-70b-versatile', displayName: 'Llama 3.3 70B Versatile', provider: LlmProviderType.groq, isFree: true),
          LlmModelInfo(id: 'deepseek-r1-distill-llama-70b', displayName: 'DeepSeek R1 Distill 70B', provider: LlmProviderType.groq, isFree: true),
          LlmModelInfo(id: 'llama-3.1-8b-instant', displayName: 'Llama 3.1 8B Instant', provider: LlmProviderType.groq, isFree: true),
        ];
      case LlmProviderType.anthropic:
        return const [
          LlmModelInfo(id: 'claude-3-5-sonnet-20241022', displayName: 'Claude 3.5 Sonnet', provider: LlmProviderType.anthropic),
          LlmModelInfo(id: 'claude-3-5-haiku-20241022', displayName: 'Claude 3.5 Haiku', provider: LlmProviderType.anthropic),
          LlmModelInfo(id: 'claude-3-opus-20240229', displayName: 'Claude 3 Opus', provider: LlmProviderType.anthropic),
        ];
      case LlmProviderType.openrouter:
        return const [
          LlmModelInfo(id: 'qwen/qwen-2.5-coder-32b-instruct:free', displayName: 'Qwen 2.5 Coder 32B Free', provider: LlmProviderType.openrouter, isFree: true),
          LlmModelInfo(id: 'meta-llama/llama-3.3-70b-instruct:free', displayName: 'Llama 3.3 70B Free', provider: LlmProviderType.openrouter, isFree: true),
          LlmModelInfo(id: 'deepseek/deepseek-r1:free', displayName: 'DeepSeek R1 Free', provider: LlmProviderType.openrouter, isFree: true),
        ];
      case LlmProviderType.ollama:
        return const [
          LlmModelInfo(id: 'qwen2.5-coder:7b', displayName: 'Qwen 2.5 Coder 7B (Local)', provider: LlmProviderType.ollama, isFree: true),
          LlmModelInfo(id: 'qwen2.5-coder:14b', displayName: 'Qwen 2.5 Coder 14B (Local)', provider: LlmProviderType.ollama, isFree: true),
          LlmModelInfo(id: 'llama3.1:8b', displayName: 'Llama 3.1 8B (Local)', provider: LlmProviderType.ollama, isFree: true),
          LlmModelInfo(id: 'deepseek-r1:7b', displayName: 'DeepSeek R1 7B (Local)', provider: LlmProviderType.ollama, isFree: true),
        ];
    }
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
}
