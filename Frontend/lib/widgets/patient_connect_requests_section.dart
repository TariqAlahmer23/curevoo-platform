// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:flutter/material.dart';

class PatientConnectRequestsSection extends StatelessWidget {
  const PatientConnectRequestsSection({
    super.key,
    required this.theme,
    required this.colorScheme,
    required this.requests,
    required this.isLoading,
    required this.loadError,
    required this.processingIds,
    required this.onRefresh,
    required this.onRespond,
    required this.buildListStatus,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final List<PatientConnectRequest> requests;
  final bool isLoading;
  final String? loadError;
  final Set<String> processingIds;
  final VoidCallback onRefresh;
  final Future<void> Function(
    PatientConnectRequest request, {
    required DoctorConnectRequestAction action,
  })
  onRespond;
  final Widget Function({
    required IconData icon,
    required String title,
    String? message,
    bool isError,
    Widget? child,
  })
  buildListStatus;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _ConnectRequestsToolbar(
            colorScheme: cs,
            requestsCount: requests.length,
            isLoading: isLoading,
            onRefresh: onRefresh,
          ),
          if (isLoading)
            buildListStatus(
              icon: Icons.mark_email_unread_outlined,
              title: context.tr('Loading connection requests...'),
              child: const CircularProgressIndicator(),
            )
          else if (loadError != null && requests.isEmpty)
            buildListStatus(
              icon: Icons.error_outline,
              title: loadError!,
              isError: true,
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr('Retry')),
              ),
            )
          else if (requests.isEmpty)
            buildListStatus(
              icon: Icons.inbox_outlined,
              title: context.tr('No connection requests for now'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = requests[index];
                final isProcessing = processingIds.contains(request.id);
                return _ConnectRequestCard(
                  colorScheme: cs,
                  request: request,
                  isProcessing: isProcessing,
                  onRespond: onRespond,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ConnectRequestsToolbar extends StatelessWidget {
  const _ConnectRequestsToolbar({
    required this.colorScheme,
    required this.requestsCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final ColorScheme colorScheme;
  final int requestsCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withOpacity(0.56),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.tertiary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.person_add_alt_1_outlined, color: cs.tertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Patient Connection Requests'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$requestsCount ${context.tr("pending requests")}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            tooltip: context.tr('Refresh'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _ConnectRequestCard extends StatelessWidget {
  const _ConnectRequestCard({
    required this.colorScheme,
    required this.request,
    required this.isProcessing,
    required this.onRespond,
  });

  final ColorScheme colorScheme;
  final PatientConnectRequest request;
  final bool isProcessing;
  final Future<void> Function(
    PatientConnectRequest request, {
    required DoctorConnectRequestAction action,
  })
  onRespond;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final normalizedSex = request.patientSex?.trim().toUpperCase();
    final requestDateLabel = _formatConnectRequestDate(request.requestedAt);
    final genderLabel = switch (normalizedSex) {
      'MALE' => context.tr('Male'),
      'FEMALE' => context.tr('Female'),
      _ => request.patientSex?.trim(),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.patientName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (requestDateLabel != null)
                Text(
                  '${context.tr("Request Date")}: $requestDateLabel',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              if (request.patientAge != null)
                Text(
                  '${context.tr("Age")}: ${request.patientAge}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              if (genderLabel != null && genderLabel.isNotEmpty)
                Text(
                  '${context.tr("Gender")}: $genderLabel',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => onRespond(
                        request,
                        action: DoctorConnectRequestAction.reject,
                      ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: 18),
                label: Text(context.tr('Reject')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withOpacity(0.4)),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => onRespond(
                        request,
                        action: DoctorConnectRequestAction.accept,
                      ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(context.tr('Accept')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _formatConnectRequestDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return rawDate;
    final local = parsed.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
