enum LlmProviderType {
  groq,
  gemini,
  anthropic,
  openrouter,
  ollama,
}

class LlmModelInfo {
  final String id;
  final String displayName;
  final LlmProviderType provider;
  final bool isFree;
  final String description;

  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.provider,
    this.isFree = false,
    this.description = '',
  });

  String get dropdownLabel => isFree ? '[FREE] $displayName' : displayName;
}

class LlmProviderUtils {
  static const List<LlmModelInfo> defaultModels = [
    // Groq Free Models
    LlmModelInfo(
      id: 'qwen-2.5-coder-32b',
      displayName: 'Qwen 2.5 Coder 32B (Groq)',
      provider: LlmProviderType.groq,
      isFree: true,
      description: 'Ultra fast (450 tok/s), #1 open-source coding & tool-calling model',
    ),
    LlmModelInfo(
      id: 'llama-3.3-70b-versatile',
      displayName: 'Llama 3.3 70B Versatile (Groq)',
      provider: LlmProviderType.groq,
      isFree: true,
      description: 'Top-tier general reasoning and multi-turn tool calling',
    ),
    LlmModelInfo(
      id: 'deepseek-r1-distill-llama-70b',
      displayName: 'DeepSeek R1 Distill 70B (Groq)',
      provider: LlmProviderType.groq,
      isFree: true,
      description: 'Deep reasoning model for complex architectural problems',
    ),

    // Google Gemini Models
    LlmModelInfo(
      id: 'gemini-2.5-flash',
      displayName: 'Gemini 2.5 Flash',
      provider: LlmProviderType.gemini,
      isFree: true,
      description: 'Latest high-speed multimodal reasoning model',
    ),
    LlmModelInfo(
      id: 'gemini-1.5-flash',
      displayName: 'Gemini 1.5 Flash',
      provider: LlmProviderType.gemini,
      isFree: true,
      description: 'Fast, lightweight Gemini model with free tier',
    ),
    LlmModelInfo(
      id: 'gemini-1.5-pro',
      displayName: 'Gemini 1.5 Pro',
      provider: LlmProviderType.gemini,
      isFree: false,
      description: 'Deep multi-file reasoning with 2M context window',
    ),
    LlmModelInfo(
      id: 'gemini-3.8-flash',
      displayName: 'Gemini 3.8 Flash',
      provider: LlmProviderType.gemini,
      isFree: true,
      description: 'Gemini 3.x series model',
    ),

    // Anthropic Claude Models
    LlmModelInfo(
      id: 'claude-3-5-sonnet-20241022',
      displayName: 'Claude 3.5 Sonnet (Anthropic)',
      provider: LlmProviderType.anthropic,
      isFree: false,
      description: 'Industry benchmark coding agent model',
    ),
    LlmModelInfo(
      id: 'claude-3-5-haiku-20241022',
      displayName: 'Claude 3.5 Haiku (Anthropic)',
      provider: LlmProviderType.anthropic,
      isFree: false,
      description: 'Blazing fast, cost-effective Claude model',
    ),

    // OpenRouter Free Models
    LlmModelInfo(
      id: 'qwen/qwen-2.5-coder-32b-instruct:free',
      displayName: 'Qwen 2.5 Coder 32B (OpenRouter)',
      provider: LlmProviderType.openrouter,
      isFree: true,
      description: 'Free hosted Qwen Coder via OpenRouter',
    ),
    LlmModelInfo(
      id: 'meta-llama/llama-3.3-70b-instruct:free',
      displayName: 'Llama 3.3 70B (OpenRouter)',
      provider: LlmProviderType.openrouter,
      isFree: true,
      description: 'Free hosted Llama 3.3 via OpenRouter',
    ),

    // Local Ollama Models
    LlmModelInfo(
      id: 'qwen2.5-coder:7b',
      displayName: 'Qwen 2.5 Coder 7B (Local Ollama)',
      provider: LlmProviderType.ollama,
      isFree: true,
      description: 'Runs 100% offline & private on your Mac via Ollama',
    ),
    LlmModelInfo(
      id: 'llama3.1:8b',
      displayName: 'Llama 3.1 8B (Local Ollama)',
      provider: LlmProviderType.ollama,
      isFree: true,
      description: 'Runs 100% offline on your Mac via Ollama',
    ),
  ];

  static LlmProviderType detectProviderFromKey(String key) {
    final trimmed = key.trim();
    if (trimmed.startsWith('gsk_')) {
      return LlmProviderType.groq;
    } else if (trimmed.startsWith('sk-ant-')) {
      return LlmProviderType.anthropic;
    } else if (trimmed.startsWith('AIzaSy')) {
      return LlmProviderType.gemini;
    } else if (trimmed.startsWith('sk-or-')) {
      return LlmProviderType.openrouter;
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.contains('11434')) {
      return LlmProviderType.ollama;
    }
    return LlmProviderType.gemini; // default
  }

  static String getProviderName(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.groq:
        return 'Groq (Free Cloud)';
      case LlmProviderType.gemini:
        return 'Google Gemini';
      case LlmProviderType.anthropic:
        return 'Anthropic Claude';
      case LlmProviderType.openrouter:
        return 'OpenRouter';
      case LlmProviderType.ollama:
        return 'Local Ollama';
    }
  }
}
