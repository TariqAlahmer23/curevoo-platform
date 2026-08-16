import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/widgets/patient_dialog_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditPatientDialog extends StatefulWidget {
  const EditPatientDialog({
    super.key,
    required this.patient,
    required this.onPatientUpdated,
  });

  final Patient patient;
  final Future<void> Function() onPatientUpdated;

  @override
  State<EditPatientDialog> createState() => _EditPatientDialogState();
}

class _EditPatientDialogState extends State<EditPatientDialog> {
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController phoneController;
  late String selectedGender;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.patient.name);
    ageController = TextEditingController(text: widget.patient.age.toString());
    phoneController = TextEditingController(text: widget.patient.phone);
    selectedGender = widget.patient.gender.toUpperCase() == 'FEMALE'
        ? 'FEMALE'
        : 'MALE';
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            context.tr("Edit Patient"),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: patientDialogDecoration(
                context,
                labelText: "Full Name",
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ageController,
              decoration: patientDialogDecoration(
                context,
                labelText: "Age",
                icon: Icons.cake_outlined,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: patientDialogDecoration(
                context,
                labelText: "Gender",
                icon: Icons.people_outline,
              ),
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
                setState(() => selectedGender = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: patientDialogDecoration(
                context,
                labelText: "Phone Number",
                icon: Icons.phone_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(context.tr("Cancel")),
        ),
        BlocBuilder<PatientsCubit, PatientsState>(
          builder: (context, state) => ElevatedButton(
            onPressed: state.isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(context.tr("Update")),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final cs = Theme.of(context).colorScheme;
    final trimmedName = nameController.text.trim();
    final trimmedPhone = phoneController.text.trim();
    final parsedAge = int.tryParse(ageController.text.trim());

    if (trimmedName.isEmpty || trimmedPhone.isEmpty || parsedAge == null || parsedAge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Please enter a valid name, age, and phone number"),
          ),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final patientsCubit = context.read<PatientsCubit>();
    final request = UpdatePatientRequest(
      fullName: trimmedName,
      phone: trimmedPhone,
      age: parsedAge,
      sex: selectedGender,
    );

    final updated = await patientsCubit.updatePatient(widget.patient.id, request);
    if (!mounted) return;

    if (updated) {
      await widget.onPatientUpdated();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Patient updated successfully!")),
          backgroundColor: Theme.of(context).colorScheme.primary,
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
        content: Text(errorMessage ?? context.tr("Failed to update patient")),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
