// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:curevoo_doctor/models/genomic_target_prioritization_result.dart';
import 'package:curevoo_doctor/providers/genomic_target_prioritization_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GenomicTargetPrioritizationPage extends StatefulWidget {
  const GenomicTargetPrioritizationPage({super.key});

  @override
  State<GenomicTargetPrioritizationPage> createState() =>
      _GenomicTargetPrioritizationPageState();
}

class _GenomicTargetPrioritizationPageState
    extends State<GenomicTargetPrioritizationPage> {
  static const List<int> _topNChoices = [10, 20, 30, 50];
  static const int _maxUploadBytes = 100 * 1024 * 1024;
  static const List<String> _allowedExtensions = ['csv'];

  _SelectedDataset? _mutationsDataset;
  _SelectedDataset? _expressionDataset;
  int _topN = 20;
  bool _showReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GenomicTargetPrioritizationCubit>().checkServiceHealth();
    });
  }

  Future<void> _pickDataset({required bool isMutations}) async {
    final cubit = context.read<GenomicTargetPrioritizationCubit>();

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        cubit.setValidationError('The selected file could not be read.');
        return;
      }

      if (bytes.length > _maxUploadBytes) {
        cubit.setValidationError(
          'Each dataset must be smaller than '
          '${_maxUploadBytes ~/ (1024 * 1024)} MB.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        final dataset = _SelectedDataset(name: file.name, bytes: bytes);
        if (isMutations) {
          _mutationsDataset = dataset;
        } else {
          _expressionDataset = dataset;
        }
      });
    } catch (_) {
      cubit.setValidationError('The file could not be selected. Try again.');
    }
  }

  void _clearDataset({required bool isMutations}) {
    setState(() {
      if (isMutations) {
        _mutationsDataset = null;
      } else {
        _expressionDataset = null;
      }
    });
  }

  Future<void> _runAnalysis() async {
    final cubit = context.read<GenomicTargetPrioritizationCubit>();
    if (cubit.state.isRunningAnalysis) return;

    final hasMutations = _mutationsDataset != null;
    final hasExpression = _expressionDataset != null;

    if (hasMutations != hasExpression) {
      cubit.setValidationError(
        'Upload both a mutation file and an RNA expression file, or leave both '
        'empty to analyze the reference cohort.',
      );
      return;
    }

    setState(() => _showReport = false);

    await cubit.runAnalysis(
      topN: _topN,
      mutationsFile: _mutationsDataset?.toMultipart('mutationsFile'),
      expressionFile: _expressionDataset?.toMultipart('expressionFile'),
    );
  }

  Future<void> _toggleReport() async {
    final cubit = context.read<GenomicTargetPrioritizationCubit>();

    if (_showReport) {
      setState(() => _showReport = false);
      return;
    }

    final markdown = await cubit.loadReport();
    if (!mounted || markdown == null) return;
    setState(() => _showReport = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<GenomicTargetPrioritizationCubit>().state;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(state),
                  const SizedBox(height: 24),
                  _buildDisclaimer(),
                  const SizedBox(height: 20),
                  _buildInputPanel(state),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _errorBanner(state.errorMessage!),
                  ],
                  if (state.isRunningAnalysis) ...[
                    const SizedBox(height: 20),
                    _buildLoadingPanel(),
                  ],
                  if (state.result != null && !state.isRunningAnalysis) ...[
                    const SizedBox(height: 20),
                    _buildResults(state.result!),
                    if (_showReport && state.reportMarkdown != null) ...[
                      const SizedBox(height: 20),
                      _buildReportPanel(state.reportMarkdown!),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GenomicTargetPrioritizationState state) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Genomic Target Prioritization',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _serviceStatusChip(state),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'AI-powered research service for ranking candidate genomic targets '
            'in lung cancer.',
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatusChip(GenomicTargetPrioritizationState state) {
    final cs = Theme.of(context).colorScheme;
    final isAvailable = state.isServiceAvailable;

    final (label, icon) = switch (isAvailable) {
      true => ('AI service online', Icons.check_circle_outline),
      false => ('AI service offline', Icons.error_outline),
      _ => ('Checking service', Icons.hourglass_empty),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.onPrimary.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.onPrimary.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: cs.onSurface),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              GenomicTargetPrioritizationResult.defaultDisclaimer,
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel(GenomicTargetPrioritizationState state) {
    final cs = Theme.of(context).colorScheme;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.biotech_outlined, color: cs.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Input',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload mutation and RNA expression CSV files, or run the '
                      'reference cohort without uploads.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final cards = [
                _uploadCard(
                  title: 'Mutation data',
                  subtitle: 'Gene-level mutation table (CSV)',
                  icon: Icons.science_outlined,
                  dataset: _mutationsDataset,
                  onPick: () => _pickDataset(isMutations: true),
                  onClear: () => _clearDataset(isMutations: true),
                  isEnabled: !state.isRunningAnalysis,
                ),
                _uploadCard(
                  title: 'RNA expression data',
                  subtitle: 'Gene x sample expression matrix (CSV)',
                  icon: Icons.show_chart_rounded,
                  dataset: _expressionDataset,
                  onPick: () => _pickDataset(isMutations: false),
                  onClear: () => _clearDataset(isMutations: false),
                  isEnabled: !state.isRunningAnalysis,
                ),
              ];

              return narrow
                  ? Column(children: cards)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards
                          .map((card) => Expanded(child: card))
                          .toList(growable: false),
                    );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Targets to return',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _topN,
                    borderRadius: BorderRadius.circular(12),
                    onChanged: state.isRunningAnalysis
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _topN = value);
                          },
                    items: _topNChoices
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('Top $value'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: state.isRunningAnalysis ? null : _runAnalysis,
                icon: state.isRunningAnalysis
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  state.isRunningAnalysis ? 'Running analysis' : 'Run Analysis',
                ),
              ),
              if (state.result != null && !state.isRunningAnalysis)
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<GenomicTargetPrioritizationCubit>().clearResult();
                    setState(() => _showReport = false);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Clear Result'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required _SelectedDataset? dataset,
    required VoidCallback onPick,
    required VoidCallback onClear,
    required bool isEnabled,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = dataset != null;

    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFile
            ? cs.primaryContainer.withOpacity(0.30)
            : cs.surfaceContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile ? cs.primary.withOpacity(0.28) : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (hasFile) ...[
            Row(
              children: [
                Icon(Icons.description_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dataset.name} (${dataset.readableSize})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isEnabled ? onPick : null,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(hasFile ? 'Replace file' : 'Choose CSV file'),
              ),
              if (hasFile)
                TextButton.icon(
                  onPressed: isEnabled ? onClear : null,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPanel() {
    final cs = Theme.of(context).colorScheme;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Running genomic target prioritization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Building gene-level features, applying safety context, ranking '
            'candidates, and matching external evidence. This can take a few '
            'minutes for uploaded datasets.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(GenomicTargetPrioritizationResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultOverview(result),
        const SizedBox(height: 18),
        _buildMetricsPanel(result.mlMetrics),
        const SizedBox(height: 18),
        _buildTargetsPanel(result),
      ],
    );
  }

  Widget _buildResultOverview(GenomicTargetPrioritizationResult result) {
    final cs = Theme.of(context).colorScheme;
    final summary = result.summary;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Analysis Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _badge(
                cs.primary,
                result.usedUploadedFiles
                    ? 'Uploaded datasets'
                    : 'Reference cohort',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.usedUploadedFiles
                ? 'Ranked from the mutation and RNA expression files you uploaded.'
                : 'Ranked from the pre-computed reference cohort produced by the '
                      'analysis pipeline.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              _tileMetric('Total targets', '${summary.totalTargets}'),
              _tileMetric('High priority', '${summary.highPriorityCount}'),
              _tileMetric('Medium priority', '${summary.mediumPriorityCount}'),
              _tileMetric('Low priority', '${summary.lowPriorityCount}'),
              _tileMetric(
                'External evidence matches',
                '${summary.externallySupportedTargets}',
              ),
            ],
          ),
          if (result.reportAvailable) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _toggleReport,
              icon: Icon(
                _showReport ? Icons.visibility_off : Icons.description_outlined,
                size: 18,
              ),
              label: Text(_showReport ? 'Hide report' : 'View generated report'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsPanel(GenomicMlMetrics metrics) {
    final cs = Theme.of(context).colorScheme;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model Evaluation Metrics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metrics.available
                ? 'Reported from the stored evaluation of the gene-label '
                      'classifier. These metrics describe how well the model '
                      'reproduces external cancer-gene evidence, not clinical '
                      'outcomes.'
                : 'No completed model evaluation is available on the AI service.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              _tileMetric('Accuracy', _formatMetric(metrics.accuracy)),
              _tileMetric('F1-score', _formatMetric(metrics.f1Score)),
              _tileMetric('MCC', _formatMetric(metrics.mcc)),
              _tileMetric('ROC-AUC', _formatMetric(metrics.rocAuc)),
              _tileMetric('PR-AUC', _formatMetric(metrics.prAuc)),
              _tileMetric(
                'Balanced accuracy',
                _formatMetric(metrics.balancedAccuracy),
              ),
              _tileMetric('Precision', _formatMetric(metrics.precision)),
              _tileMetric('Recall', _formatMetric(metrics.recall)),
            ],
          ),
          if (metrics.available) ...[
            const SizedBox(height: 18),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            _kv('Model', metrics.modelName ?? 'Unavailable'),
            _kv('Label set', metrics.labelMode ?? 'Unavailable'),
            _kv('Evaluation', metrics.evaluationStrategy ?? 'Unavailable'),
            if (metrics.labeledGenes != null)
              _kv(
                'Labeled genes',
                '${metrics.labeledGenes} '
                    '(${metrics.positiveGenes ?? 0} positive, '
                    '${metrics.negativeGenes ?? 0} negative)',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetsPanel(GenomicTargetPrioritizationResult result) {
    final cs = Theme.of(context).colorScheme;

    if (result.topTargets.isEmpty) {
      return _emptyState(
        'No ranked targets returned',
        'The analysis completed but produced no ranked targets.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Ranked Targets',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ranked candidate genomic targets with evidence tier, safety context, '
          'and ranking explanation.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ...result.topTargets.map(_targetCard),
      ],
    );
  }

  Widget _targetCard(GenomicRankedTarget target) {
    final cs = Theme.of(context).colorScheme;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${target.rank}',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.gene,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target.targetCategory,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _badge(_priorityColor(target.priority), target.priority),
                  _badge(
                    cs.secondary,
                    'Score ${target.rankingScore.toStringAsFixed(3)}',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kv('Evidence tier', target.evidenceTierLabel),
          if (target.evidenceTierExplanation != null)
            _kv('Tier basis', target.evidenceTierExplanation!),
          _kv(
            'Safety risk',
            target.safetyScore == null
                ? target.safetyRiskLabel
                : '${target.safetyRiskLabel} '
                      '(safety score ${target.safetyScore!.toStringAsFixed(2)})',
          ),
          if (target.normalLungTpm != null)
            _kv(
              'Normal lung expression',
              '${target.normalLungTpm!.toStringAsFixed(2)} TPM',
            ),
          if (target.safetyNote != null) _kv('Safety note', target.safetyNote!),
          _kv('Explanation', target.explanation),
          _kv(
            'External evidence',
            target.hasExternalEvidence
                ? '${target.externalEvidenceSources.join(', ')}'
                      '${target.externalEvidenceConfidence == null ? '' : ' (${target.externalEvidenceConfidence})'}'
                : 'No external evidence match',
          ),
        ],
      ),
    );
  }

  Widget _buildReportPanel(String markdown) {
    final cs = Theme.of(context).colorScheme;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generated Research Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 480),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  markdown,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    final cs = Theme.of(context).colorScheme;

    return switch (priority.toLowerCase()) {
      'high' => cs.error,
      'medium' => Colors.orange.shade800,
      _ => cs.onSurfaceVariant,
    };
  }

  String _formatMetric(double? value) {
    if (value == null) return 'Unavailable';
    return value.toStringAsFixed(4);
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _tileMetric(String label, String value) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Unavailable' : value,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? 'Unknown' : value)),
        ],
      ),
    );
  }

  Widget _badge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDataset {
  const _SelectedDataset({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get readableSize {
    final kilobytes = bytes.length / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }

  MultipartFileData toMultipart(String field) {
    return MultipartFileData(field: field, bytes: bytes, filename: name);
  }
}
