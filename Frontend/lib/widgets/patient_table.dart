// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:flutter/material.dart';

class PatientTable extends StatelessWidget {
  final List<Patient> patients;
  final Function(Patient) onViewPressed;
  final Function(Patient) onEditPressed;

  const PatientTable({
    super.key,
    required this.patients,
    required this.onViewPressed,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    const rowHeight = 86.0;
    final bodyHeight = math.min(patients.length * rowHeight, 560.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 780;
        final list = ListView.builder(
          itemCount: patients.length,
          itemExtent: isNarrow ? 132 : rowHeight,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final p = patients[index];
            return PatientRow(
              patient: p,
              onViewPressed: onViewPressed,
              onEditPressed: onEditPressed,
              isCompact: isNarrow,
            );
          },
        );

        return Column(
          children: [
            if (!isNarrow) const TableHeader(),
            SizedBox(
              height: isNarrow
                  ? math.min(patients.length * 132.0, 620.0)
                  : bodyHeight,
              child: list,
            ),
          ],
        );
      },
    );
  }
}

class TableHeader extends StatelessWidget {
  const TableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
      letterSpacing: 0.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 52),
          Expanded(
            flex: 3,
            child: Text(context.tr("Patient"), style: headerStyle),
          ),
          Expanded(flex: 1, child: Text(context.tr("Age"), style: headerStyle)),
          Expanded(
            flex: 2,
            child: Text(context.tr("Gender"), style: headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              context.tr("Phone"),
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(context.tr("Actions"), style: headerStyle),
          ),
        ],
      ),
    );
  }
}

class PatientRow extends StatefulWidget {
  final Patient patient;
  final Function(Patient) onViewPressed;
  final Function(Patient) onEditPressed;
  final bool isCompact;

  const PatientRow({
    super.key,
    required this.patient,
    required this.onViewPressed,
    required this.onEditPressed,
    this.isCompact = false,
  });

  @override
  State<PatientRow> createState() => _PatientRowState();
}

class _PatientRowState extends State<PatientRow> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final cs = Theme.of(context).colorScheme;
    final genderColor = p.gender.toLowerCase() == 'male'
        ? Colors.blue
        : p.gender.toLowerCase() == 'female'
        ? Colors.pink
        : cs.secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onViewPressed(p),
          borderRadius: BorderRadius.circular(0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 18 : 24,
              vertical: widget.isCompact ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: isHovered
                  ? cs.primary.withOpacity(0.06)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: widget.isCompact
                ? Column(
                    children: [
                      Row(
                        children: [
                          _buildAvatar(cs, p),
                          const SizedBox(width: 14),
                          Expanded(child: _buildNameBlock(cs, p)),
                          const SizedBox(width: 10),
                          _buildGenderChip(cs, p, genderColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            context,
                            label: "View",
                            icon: Icons.visibility_outlined,
                            onPressed: () => widget.onViewPressed(p),
                            isPrimary: false,
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            context,
                            label: "Edit",
                            icon: Icons.edit_outlined,
                            onPressed: () => widget.onEditPressed(p),
                            isPrimary: true,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _buildAvatar(cs, p),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildNameBlock(cs, p)),
                      Expanded(
                        flex: 1,
                        child: Text(
                          p.age.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildGenderChip(cs, p, genderColor),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.phone,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                context,
                                label: "View",
                                icon: Icons.visibility_outlined,
                                onPressed: () => widget.onViewPressed(p),
                                isPrimary: false,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildActionButton(
                                context,
                                label: "Edit",
                                icon: Icons.edit_outlined,
                                onPressed: () => widget.onEditPressed(p),
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs, Patient p) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.secondary.withOpacity(0.78)],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: cs.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildNameBlock(ColorScheme cs, Patient p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          p.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${p.age} ${context.tr("years")}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildGenderChip(ColorScheme cs, Patient p, Color genderColor) {
    final isMale = p.gender.toLowerCase() == 'male';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: genderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: genderColor.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMale ? Icons.male : Icons.female,
            size: 13,
            color: genderColor,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              p.gender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: genderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final cs = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: isPrimary ? cs.primary : cs.onSurfaceVariant,
        backgroundColor: isPrimary
            ? cs.primary.withOpacity(0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: !isPrimary
              ? BorderSide(color: cs.outline.withOpacity(0.5))
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            context.tr(label),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
