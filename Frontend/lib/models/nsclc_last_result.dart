class NsclcLastResult {
  const NsclcLastResult({
    required this.predictionRunId,
    required this.patientId,
    required this.patientType,
    required this.predictionRunStored,
    required this.packageSlug,
    required this.cancerType,
    required this.predictionVersion,
    required this.summaryText,
    required this.supportLabel,
    required this.earlyFailureRisk,
    required this.durableBenefitLikelihood,
    required this.resistanceInterpretation,
    required this.createdAt,
  });

  final String predictionRunId;
  final String patientId;
  final String? patientType;
  final bool predictionRunStored;
  final String packageSlug;
  final String cancerType;
  final String? predictionVersion;
  final String? summaryText;
  final String? supportLabel;
  final NsclcRiskSignal earlyFailureRisk;
  final NsclcRiskSignal durableBenefitLikelihood;
  final NsclcResistanceInterpretation resistanceInterpretation;
  final DateTime? createdAt;

  factory NsclcLastResult.fromMap(Map<String, dynamic> source) {
    return NsclcLastResult(
      predictionRunId:
          _readString(source, const ['predictionRunId', 'runId', 'id']) ?? '',
      patientId: _readString(source, const ['patientId']) ?? '',
      patientType: _readString(source, const ['patientType']),
      predictionRunStored:
          _readBool(source, const ['predictionRunStored']) ?? false,
      packageSlug: _readString(source, const ['packageSlug']) ?? 'nsclc',
      cancerType: _readString(source, const ['cancerType']) ?? 'NSCLC',
      predictionVersion: _readString(source, const ['predictionVersion']),
      summaryText: _readString(source, const ['summaryText', 'summary']),
      supportLabel: _readString(source, const ['supportLabel']),
      earlyFailureRisk: NsclcRiskSignal.fromMap(
        _readMap(source, const ['earlyFailureRisk']) ?? const {},
        fallbackTitle: 'Predicted Early Progression Risk',
      ),
      durableBenefitLikelihood: NsclcRiskSignal.fromMap(
        _readMap(source, const ['durableBenefitLikelihood']) ?? const {},
        fallbackTitle: 'Predicted Durable Benefit Signal',
      ),
      resistanceInterpretation: NsclcResistanceInterpretation.fromMap(
        _readMap(source, const ['resistanceInterpretation']) ?? const {},
      ),
      createdAt: DateTime.tryParse(
        _readString(source, const ['createdAt', 'created_at']) ?? '',
      ),
    );
  }
}

class NsclcRiskSignal {
  const NsclcRiskSignal({
    required this.title,
    required this.probability,
    required this.riskLevel,
    required this.subtitle,
  });

  final String title;
  final double probability;
  final String? riskLevel;
  final String? subtitle;

  factory NsclcRiskSignal.fromMap(
    Map<String, dynamic> source, {
    required String fallbackTitle,
  }) {
    var probability =
        _readDouble(source, const ['probability', 'score', 'value']) ?? 0;
    if (probability > 1) {
      probability = probability / 100;
    }

    return NsclcRiskSignal(
      title: _readString(source, const ['title', 'label']) ?? fallbackTitle,
      probability: probability,
      riskLevel: _readString(source, const ['riskLevel', 'risk_level']),
      subtitle: _readString(source, const ['subtitle', 'message']),
    );
  }
}

class NsclcResistanceInterpretation {
  const NsclcResistanceInterpretation({
    required this.summary,
    required this.signals,
  });

  final String? summary;
  final List<NsclcResistanceSignal> signals;

  factory NsclcResistanceInterpretation.fromMap(Map<String, dynamic> source) {
    final rawSignals = source['signals'];
    final signals = rawSignals is List
        ? rawSignals
              .whereType<Map>()
              .map(
                (entry) => NsclcResistanceSignal.fromMap(
                  entry.map(
                    (key, dynamic value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <NsclcResistanceSignal>[];
    return NsclcResistanceInterpretation(
      summary: _readString(source, const ['summary']),
      signals: signals,
    );
  }
}

class NsclcResistanceSignal {
  const NsclcResistanceSignal({
    required this.tag,
    required this.label,
    required this.message,
  });

  final String tag;
  final String label;
  final String message;

  factory NsclcResistanceSignal.fromMap(Map<String, dynamic> source) {
    return NsclcResistanceSignal(
      tag: _readString(source, const ['tag']) ?? '',
      label: _readString(source, const ['label']) ?? '',
      message: _readString(source, const ['message']) ?? '',
    );
  }
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

double? _readDouble(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool? _readBool(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    if (value is num) return value != 0;
  }
  return null;
}

Map<String, dynamic>? _readMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (innerKey, dynamic innerValue) => MapEntry(innerKey.toString(), innerValue),
      );
    }
  }
  return null;
}
