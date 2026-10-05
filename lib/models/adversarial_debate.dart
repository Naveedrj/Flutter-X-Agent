import 'llm_provider.dart';

enum AdversarialAttackFocus {
  comprehensive,
  security,
  performance,
  stressTesting,
}

extension AdversarialAttackFocusExtension on AdversarialAttackFocus {
  String get label {
    switch (this) {
      case AdversarialAttackFocus.comprehensive:
        return '🎯 Comprehensive (All-Round)';
      case AdversarialAttackFocus.security:
        return '🛡️ Security & Vulnerabilities';
      case AdversarialAttackFocus.performance:
        return '⚡ Performance & O(N) Efficiency';
      case AdversarialAttackFocus.stressTesting:
        return '🧪 Edge Cases & Stress Testing';
    }
  }

  String get shortLabel {
    switch (this) {
      case AdversarialAttackFocus.comprehensive:
        return 'Comprehensive';
      case AdversarialAttackFocus.security:
        return 'Security';
      case AdversarialAttackFocus.performance:
        return 'Performance';
      case AdversarialAttackFocus.stressTesting:
        return 'Stress Testing';
    }
  }
}

class AdversarialConfig {
  LlmProviderType blueProvider;
  String blueModel;
  String blueApiKey;

  LlmProviderType redProvider;
  String redModel;
  String redApiKey;

  int maxRounds;
  AdversarialAttackFocus focus;
  double temperature;

  AdversarialConfig({
    required this.blueProvider,
    required this.blueModel,
    required this.blueApiKey,
    required this.redProvider,
    required this.redModel,
    required this.redApiKey,
    this.maxRounds = 3,
    this.focus = AdversarialAttackFocus.comprehensive,
    this.temperature = 0.3,
  });

  AdversarialConfig copyWith({
    LlmProviderType? blueProvider,
    String? blueModel,
    String? blueApiKey,
    LlmProviderType? redProvider,
    String? redModel,
    String? redApiKey,
    int? maxRounds,
    AdversarialAttackFocus? focus,
    double? temperature,
  }) {
    return AdversarialConfig(
      blueProvider: blueProvider ?? this.blueProvider,
      blueModel: blueModel ?? this.blueModel,
      blueApiKey: blueApiKey ?? this.blueApiKey,
      redProvider: redProvider ?? this.redProvider,
      redModel: redModel ?? this.redModel,
      redApiKey: redApiKey ?? this.redApiKey,
      maxRounds: maxRounds ?? this.maxRounds,
      focus: focus ?? this.focus,
      temperature: temperature ?? this.temperature,
    );
  }
}

enum DebateTurnType {
  blueProposal,
  redAttack,
  blueDefense,
  consensus,
}

class DebateTurn {
  final String id;
  final int round;
  final DebateTurnType type;
  final String speaker;
  final String modelName;
  final String summary;
  final String fullContent;
  final String? codeSnippet;
  final List<String> vulnerabilitiesFound;
  final List<String> optimizationsProposed;
  final bool isConsensus;
  final int score;
  final DateTime timestamp;

  DebateTurn({
    required this.id,
    required this.round,
    required this.type,
    required this.speaker,
    required this.modelName,
    required this.summary,
    required this.fullContent,
    this.codeSnippet,
    this.vulnerabilitiesFound = const [],
    this.optimizationsProposed = const [],
    this.isConsensus = false,
    this.score = 70,
    required this.timestamp,
  });

  bool get isBlue => type == DebateTurnType.blueProposal || type == DebateTurnType.blueDefense;
  bool get isRed => type == DebateTurnType.redAttack;
}

enum AdversarialSessionStatus {
  idle,
  runningBlue,
  runningRed,
  completed,
  error,
}

class AdversarialSession {
  final String id;
  final String taskPrompt;
  final AdversarialConfig config;
  final List<DebateTurn> turns;
  AdversarialSessionStatus status;
  String? finalHardenedCode;
  String? targetFilePath;
  int totalVulnerabilitiesNeutralized;
  int totalOptimizationsApplied;
  bool consensusReached;
  String? errorMessage;
  final DateTime createdAt;

  AdversarialSession({
    required this.id,
    required this.taskPrompt,
    required this.config,
    List<DebateTurn>? turns,
    this.status = AdversarialSessionStatus.idle,
    this.finalHardenedCode,
    this.targetFilePath,
    this.totalVulnerabilitiesNeutralized = 0,
    this.totalOptimizationsApplied = 0,
    this.consensusReached = false,
    this.errorMessage,
    required this.createdAt,
  }) : turns = turns ?? [];
}
