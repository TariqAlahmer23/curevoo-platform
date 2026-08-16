// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:flutter/material.dart';

InputDecoration patientDialogDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  IconData? icon,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    labelStyle: TextStyle(color: cs.onSurfaceVariant),
    hintStyle: hintText == null
        ? null
        : TextStyle(
            color: cs.onSurfaceVariant.withOpacity(0.6),
            fontSize: 14,
          ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: icon == null ? null : Icon(icon, color: cs.primary),
  );
}

Widget patientDialogFieldLabel(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return Text(
    context.tr(text),
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: cs.onSurface,
    ),
  );
}
