class GenomicTargetPrioritizationResult {
  const GenomicTargetPrioritizationResult({
    required this.runId,
    required this.status,
    required this.dataSource,
    required this.generatedAt,
    required this.topTargets,
    required this.summary,
    required this.mlMetrics,
    required this.reportAvailable,
    required this.reportUrl,
    required this.disclaimer,
  });

  final String runId;
  final String status;
  final String dataSource;
  final DateTime? generatedAt;
  final List<GenomicRankedTarget> topTargets;
  final GenomicAnalysisSummary summary;
  final GenomicMlMetrics mlMetrics;
  final bool reportAvailable;
  final String? reportUrl;
  final String disclaimer;

  static const String defaultDisclaimer =
      'Research-use only. This service does not provide diagnosis or treatment decisions.';

  bool get usedUploadedFiles => dataSource == 'uploaded_files';

  factory GenomicTargetPrioritizationResult.fromMap(Map<String, dynamic> source) {
    final rawTargets = source['topTargets'];
    final targets = rawTargets is List
        ? rawTargets
              .whereType<Map>()
              .map(
                (entry) => GenomicRankedTarget.fromMap(
                  entry.map(
                    (key, dynamic value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <GenomicRankedTarget>[];

    return GenomicTargetPrioritizationResult(
      runId: _readString(source, const ['runId', 'run_id']) ?? '',
      status: _readString(source, const ['status']) ?? 'success',
      dataSource:
          _readString(source, const ['dataSource', 'data_source']) ??
          'precomputed_cohort',
      generatedAt: DateTime.tryParse(
        _readString(source, const ['generatedAt', 'generated_at']) ?? '',
      ),
      topTargets: targets,
      summary: GenomicAnalysisSummary.fromMap(
        _readMap(source, const ['summary']) ?? const {},
      ),
      mlMetrics: GenomicMlMetrics.fromMap(
        _readMap(source, const ['mlMetrics', 'ml_metrics']) ?? const {},
      ),
      reportAvailable: _readBool(source, const ['reportAvailable']) ?? false,
      reportUrl: _readString(source, const ['reportUrl']),
      disclaimer: _readString(source, const ['disclaimer']) ?? defaultDisclaimer,
    );
  }
}

class GenomicRankedTarget {
  const GenomicRankedTarget({
    required this.rank,
    required this.gene,
    required this.rankingScore,
    required this.priority,
    required this.evidenceTier,
    required this.targetCategory,
    required this.safetyRisk,
    required this.safetyScore,
    required this.safetyNote,
    required this.normalLungTpm,
    required this.explanation,
    required this.evidenceTierExplanation,
    required this.externalEvidenceSources,
    required this.externalEvidenceConfidence,
  });

  final int rank;
  final String gene;
  final double rankingScore;
  final String priority;
  final String evidenceTier;
  final String targetCategory;
  final String safetyRisk;
  final double? safetyScore;
  final String? safetyNote;
  final double? normalLungTpm;
  final String explanation;
  final String? evidenceTierExplanation;
  final List<String> externalEvidenceSources;
  final String? externalEvidenceConfidence;

  /// Human-readable evidence tier, e.g. `Tier 1 Strong Integrated Target`.
  String get evidenceTierLabel => evidenceTier.replaceAll('_', ' ').trim();

  /// Human-readable safety risk, e.g. `High Normal Expression`.
  String get safetyRiskLabel => safetyRisk.replaceAll('_', ' ').trim();

  bool get hasExternalEvidence => externalEvidenceSources.isNotEmpty;

  factory GenomicRankedTarget.fromMap(Map<String, dynamic> source) {
    final rawSources = source['externalEvidenceSources'];
    final evidenceSources = rawSources is List
        ? rawSources
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return GenomicRankedTarget(
      rank: _readDouble(source, const ['rank'])?.round() ?? 0,
      gene: _readString(source, const ['gene', 'gene_name']) ?? 'Unknown',
      rankingScore:
          _readDouble(source, const ['rankingScore', 'ranking_score']) ?? 0,
      priority: _readString(source, const ['priority']) ?? 'Low',
      evidenceTier:
          _readString(source, const ['evidenceTier', 'evidence_tier']) ??
          'Unknown',
      targetCategory:
          _readString(source, const ['targetCategory', 'target_category']) ??
          'Unknown',
      safetyRisk:
          _readString(source, const ['safetyRisk', 'safety_risk']) ?? 'Unknown',
      safetyScore: _readDouble(source, const ['safetyScore', 'safety_score']),
      safetyNote: _readString(source, const ['safetyNote', 'safety_note']),
      normalLungTpm: _readDouble(
        source,
        const ['normalLungTpm', 'normal_lung_tpm'],
      ),
      explanation: _readString(source, const ['explanation']) ?? '',
      evidenceTierExplanation: _readString(
        source,
        const ['evidenceTierExplanation', 'evidence_tier_explanation'],
      ),
      externalEvidenceSources: evidenceSources,
      externalEvidenceConfidence: _readString(
        source,
        const ['externalEvidenceConfidence', 'external_evidence_confidence'],
      ),
    );
  }
}

class GenomicAnalysisSummary {
  const GenomicAnalysisSummary({
    required this.totalTargets,
    required this.highPriorityCount,
    required this.mediumPriorityCount,
    required this.lowPriorityCount,
    required this.externallySupportedTargets,
    required this.evidenceTierCounts,
  });

  final int totalTargets;
  final int highPriorityCount;
  final int mediumPriorityCount;
  final int lowPriorityCount;
  final int externallySupportedTargets;
  final Map<String, int> evidenceTierCounts;

  factory GenomicAnalysisSummary.fromMap(Map<String, dynamic> source) {
    final rawTierCounts = _readMap(source, const ['evidenceTierCounts']);
    final tierCounts = <String, int>{};
    rawTierCounts?.forEach((key, dynamic value) {
      if (value is num) tierCounts[key] = value.toInt();
    });

    return GenomicAnalysisSummary(
      totalTargets: _readDouble(source, const ['totalTargets'])?.round() ?? 0,
      highPriorityCount:
          _readDouble(source, const ['highPriorityCount'])?.round() ?? 0,
      mediumPriorityCount:
          _readDouble(source, const ['mediumPriorityCount'])?.round() ?? 0,
      lowPriorityCount:
          _readDouble(source, const ['lowPriorityCount'])?.round() ?? 0,
      externallySupportedTargets:
          _readDouble(source, const ['externallySupportedTargets'])?.round() ?? 0,
      evidenceTierCounts: tierCounts,
    );
  }
}

class GenomicMlMetrics {
  const GenomicMlMetrics({
    required this.accuracy,
    required this.balancedAccuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.mcc,
    required this.rocAuc,
    required this.prAuc,
    required this.available,
    required this.modelName,
    required this.labelMode,
    required this.evaluationStrategy,
    required this.labeledGenes,
    required this.positiveGenes,
    required this.negativeGenes,
  });

  final double? accuracy;
  final double? balancedAccuracy;
  final double? precision;
  final double? recall;
  final double? f1Score;
  final double? mcc;
  final double? rocAuc;
  final double? prAuc;
  final bool available;
  final String? modelName;
  final String? labelMode;
  final String? evaluationStrategy;
  final int? labeledGenes;
  final int? positiveGenes;
  final int? negativeGenes;

  factory GenomicMlMetrics.fromMap(Map<String, dynamic> source) {
    return GenomicMlMetrics(
      accuracy: _readDouble(source, const ['accuracy']),
      balancedAccuracy: _readDouble(source, const ['balancedAccuracy']),
      precision: _readDouble(source, const ['precision']),
      recall: _readDouble(source, const ['recall']),
      f1Score: _readDouble(source, const ['f1Score']),
      mcc: _readDouble(source, const ['mcc']),
      rocAuc: _readDouble(source, const ['rocAuc']),
      prAuc: _readDouble(source, const ['prAuc']),
      available: _readBool(source, const ['available']) ?? false,
      modelName: _readString(source, const ['modelName']),
      labelMode: _readString(source, const ['labelMode']),
      evaluationStrategy: _readString(source, const ['evaluationStrategy']),
      labeledGenes: _readDouble(source, const ['labeledGenes'])?.round(),
      positiveGenes: _readDouble(source, const ['positiveGenes'])?.round(),
      negativeGenes: _readDouble(source, const ['negativeGenes'])?.round(),
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
        (innerKey, dynamic innerValue) =>
            MapEntry(innerKey.toString(), innerValue),
      );
    }
  }
  return null;
}
