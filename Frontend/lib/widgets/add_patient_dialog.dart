// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/widgets/patient_dialog_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddPatientDialog extends StatefulWidget {
  const AddPatientDialog({
    super.key,
    required this.onPatientCreated,
  });

  final Future<void> Function() onPatientCreated;

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();
  String selectedSex = 'MALE';

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final inset = EdgeInsets.all(screenWidth < 600 ? 12 : 20);
    final dialogWidth = (screenWidth - inset.horizontal).clamp(
      320.0,
      600.0,
    ).toDouble();
    final useSingleColumn = dialogWidth < 560;

    return Dialog(
      insetPadding: inset,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("Add New Patient"),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          "Create a new patient profile and medical record",
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (useSingleColumn)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    patientDialogFieldLabel(context, "Full Name"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: patientDialogDecoration(
                        context,
                        hintText: context.tr("Enter full name"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    patientDialogFieldLabel(context, "Phone"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: patientDialogDecoration(
                        context,
                        hintText: context.tr("Enter phone number"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    patientDialogFieldLabel(context, "Age"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: patientDialogDecoration(
                        context,
                        hintText: context.tr("Enter age"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    patientDialogFieldLabel(context, "Sex"),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSex,
                      decoration: patientDialogDecoration(context),
                      icon: Icon(Icons.arrow_drop_down, color: cs.primary),
                      dropdownColor: cs.surface,
                      items: [
                        DropdownMenuItem(
                          value: 'MALE',
                          child: Text(context.tr('Male')),
                        ),
                        DropdownMenuItem(
                          value: 'FEMALE',
                          child: Text(context.tr('Female')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedSex = value);
                      },
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          patientDialogFieldLabel(context, "Full Name"),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: patientDialogDecoration(
                              context,
                              hintText: context.tr("Enter full name"),
                            ),
                          ),
                          const SizedBox(height: 20),
                          patientDialogFieldLabel(context, "Phone"),
                          const SizedBox(height: 8),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: patientDialogDecoration(
                              context,
                              hintText: context.tr("Enter phone number"),
                            ),
                          ),
                          const SizedBox(height: 20),
                          patientDialogFieldLabel(context, "Age"),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: patientDialogDecoration(
                              context,
                              hintText: context.tr("Enter age"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          patientDialogFieldLabel(context, "Sex"),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSex,
                            decoration: patientDialogDecoration(context),
                            icon: Icon(Icons.arrow_drop_down, color: cs.primary),
                            dropdownColor: cs.surface,
                            items: [
                              DropdownMenuItem(
                                value: 'MALE',
                                child: Text(context.tr('Male')),
                              ),
                              DropdownMenuItem(
                                value: 'FEMALE',
                                child: Text(context.tr('Female')),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => selectedSex = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  BlocBuilder<PatientsCubit, PatientsState>(
                    builder: (context, state) => TextButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        foregroundColor: cs.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(context.tr("Cancel")),
                    ),
                  ),
                  BlocBuilder<PatientsCubit, PatientsState>(
                    builder: (context, state) => FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: state.isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(context.tr("Add Patient")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final patientsCubit = context.read<PatientsCubit>();
    final age = int.tryParse(ageController.text);

    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        age == null ||
        age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Please fill all fields")),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final request = CreatePatientRequest(
      fullName: nameController.text.trim(),
      phone: phoneController.text.trim(),
      age: age,
      sex: selectedSex,
    );

    final created = await patientsCubit.createPatient(request);
    if (!mounted) return;

    if (created) {
      await widget.onPatientCreated();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Patient added successfully!")),
          backgroundColor: cs.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final errorMessage = patientsCubit.state.errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? context.tr("Failed to create patient"),
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
