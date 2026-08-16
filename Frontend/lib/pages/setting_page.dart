// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/doctor_available_time.dart';
import 'package:curevoo_doctor/providers/available_times_cubit.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/language_cubit.dart';
import 'package:curevoo_doctor/providers/theme_cubit.dart';
import 'package:curevoo_doctor/providers/theme_style_cubit.dart';
import 'package:curevoo_doctor/theme/app_theme.dart';
import 'package:curevoo_doctor/widgets/password_validator.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<int> _dayOrder = [1, 2, 3, 4, 5, 6, 0];
  static const Map<int, String> _dayKeyByIndex = {
    0: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  final TextEditingController deleteConfirmationController =
      TextEditingController();
  final _changePasswordFormKey = GlobalKey<FormState>();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    context.read<AvailableTimesCubit>().loadAvailableTimes();
  }

  void showSnackBar(
    BuildContext context,
    String message, {
    bool isSuccess = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? cs.secondary : cs.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    deleteConfirmationController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_changePasswordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);

    final success = await context.read<AuthCubit>().changePassword(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
    );

    if (!mounted) return;

    setState(() => _isChangingPassword = false);

    if (success) {
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      showSnackBar(context, context.tr("Password changed successfully."));
      return;
    }

    showSnackBar(
      context,
      context.read<AuthCubit>().state.errorMessage ??
          context.tr("Failed to change password. Please try again."),
      isSuccess: false,
    );
  }

  Future<void> _handleDeleteAccount() async {
    final input = deleteConfirmationController.text.trim().toLowerCase();
    const arabicDeleteKeyword = '\u062d\u0630\u0641';
    final validInputs = {'delete', arabicDeleteKeyword};

    if (!validInputs.contains(input)) {
      showSnackBar(
        context,
        context.tr("Please type delete keyword to confirm"),
        isSuccess: false,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.tr("Delete Account")),
          content: Text(
            context.tr(
              "This action is permanent and cannot be undone. Are you sure?",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr("Cancel")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.tr("Delete")),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await context.read<AuthCubit>().deleteAccount();
    if (!mounted) return;

    deleteConfirmationController.clear();

    if (success) {
      showSnackBar(context, context.tr("Account deleted successfully"));
      return;
    }

    showSnackBar(
      context,
      context.read<AuthCubit>().state.errorMessage ??
          context.tr("Failed to delete account. Please try again."),
      isSuccess: false,
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    deleteConfirmationController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr("Delete Account")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr("Type delete keyword to continue.")),
              const SizedBox(height: 12),
              TextField(
                controller: deleteConfirmationController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr("Type delete keyword"),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr("Cancel")),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _handleDeleteAccount();
              },
              child: Text(context.tr("Confirm Delete")),
            ),
          ],
        );
      },
    );
  }

  WorkingDay _toWorkingDay(DoctorAvailableTime time) {
    return WorkingDay(
      dayOfWeek: time.dayOfWeek,
      day: _dayKeyByIndex[time.dayOfWeek] ?? 'Unknown',
      startTime: time.from ?? '09:00',
      endTime: time.to ?? '17:00',
      enabled: time.isOn,
    );
  }

  DoctorAvailableTime _toAvailableTime(WorkingDay workingDay) {
    final from = workingDay.startTime.trim();
    final to = workingDay.endTime.trim();
    return DoctorAvailableTime(
      dayOfWeek: workingDay.dayOfWeek,
      from: workingDay.enabled ? (from.isEmpty ? '09:00' : from) : null,
      to: workingDay.enabled ? (to.isEmpty ? '17:00' : to) : null,
      isOn: workingDay.enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, theme, cs),
                    const SizedBox(height: 24),

                    SettingsCard(
                      title: t("Application Language"),
                      icon: Icons.language_outlined,
                      child: BlocBuilder<LanguageCubit, Locale>(
                        builder: (context, locale) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t("Choose your preferred language"),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: locale.languageCode,
                                items: [
                                  DropdownMenuItem(
                                    value: 'en',
                                    child: Text(t("English")),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ar',
                                    child: Text(t("Arabic")),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: t("Language"),
                                  prefixIcon: const Icon(
                                    Icons.translate_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: cs.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: cs.surfaceContainer.withOpacity(
                                    0.45,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(16),
                                onChanged: (value) {
                                  if (value == null) return;
                                  context.read<LanguageCubit>().setLanguage(
                                    value,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    SettingsCard(
                      title: t("Theme Mode"),
                      icon: Icons.palette_outlined,
                      child: BlocBuilder<ThemeStyleCubit, String>(
                        builder: (context, _) {
                          return BlocBuilder<ThemeCubit, ThemeMode>(
                            builder: (context, themeMode) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t("Choose how the application looks"),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: const [
                                      _ThemeStyleChoice(
                                        themeKey: MyTheme.themeBlue,
                                        label: 'Default',
                                        color: Colors.blue,
                                      ),
                                      _ThemeStyleChoice(
                                        themeKey: MyTheme.themeGreen,
                                        label: 'Green',
                                        color: Colors.green,
                                      ),
                                      _ThemeStyleChoice(
                                        themeKey: MyTheme.themeIndigo,
                                        label: 'Indigo',
                                        color: Colors.indigo,
                                      ),
                                      _ThemeStyleChoice(
                                        themeKey: MyTheme.themeRose,
                                        label: 'Rose',
                                        color: Colors.pink,
                                      ),
                                      _ThemeStyleChoice(
                                        themeKey: MyTheme.themeCyan,
                                        label: 'Cyan',
                                        color: Colors.cyan,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow =
                                          constraints.maxWidth < 520;
                                      final light = ThemeModeButton(
                                        label: t("Light mode"),
                                        icon: Icons.light_mode,
                                        isSelected:
                                            themeMode == ThemeMode.light,
                                        onPressed: () {
                                          context
                                              .read<ThemeCubit>()
                                              .setThemeMode(ThemeMode.light);
                                        },
                                      );
                                      final dark = ThemeModeButton(
                                        label: t("Dark mode"),
                                        icon: Icons.dark_mode,
                                        isSelected: themeMode == ThemeMode.dark,
                                        onPressed: () {
                                          context
                                              .read<ThemeCubit>()
                                              .setThemeMode(ThemeMode.dark);
                                        },
                                      );

                                      if (isNarrow) {
                                        return Column(
                                          children: [
                                            light,
                                            const SizedBox(height: 12),
                                            dark,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(child: light),
                                          const SizedBox(width: 12),
                                          Expanded(child: dark),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    SettingsCard(
                      title: t("Change Password"),
                      icon: Icons.lock_reset_outlined,
                      child: Form(
                        key: _changePasswordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(
                                "Update your password by entering your current password first.",
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Label(text: t("Current Password")),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: currentPasswordController,
                              obscureText: _obscureCurrentPassword,
                              decoration: _passwordDecoration(
                                context,
                                hintText: t("Enter your current password"),
                                obscureText: _obscureCurrentPassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscureCurrentPassword =
                                        !_obscureCurrentPassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return context.tr(
                                    "Please enter your current password",
                                  );
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Label(text: t("New Password")),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: newPasswordController,
                              obscureText: _obscureNewPassword,
                              decoration: _passwordDecoration(
                                context,
                                hintText: t("Enter your new password"),
                                obscureText: _obscureNewPassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) {
                                  return context.tr(
                                    "Please enter a new password",
                                  );
                                }
                                final formatError =
                                    PasswordValidator.validateFormat(password);
                                if (formatError != null) {
                                  return context.tr(formatError);
                                }
                                if (password ==
                                    currentPasswordController.text) {
                                  return context.tr(
                                    "New password must be different from current password",
                                  );
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Label(text: t("Confirm Password")),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: _passwordDecoration(
                                context,
                                hintText: t("Confirm your new password"),
                                obscureText: _obscureConfirmPassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return context.tr(
                                    "Please confirm your password",
                                  );
                                }
                                if (value != newPasswordController.text) {
                                  return context.tr("Passwords do not match");
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isChangingPassword
                                    ? null
                                    : _handleChangePassword,
                                icon: _isChangingPassword
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(t("Change Password")),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SettingsCard(
                      title: t("Working Hours"),
                      icon: Icons.schedule_outlined,
                      child: BlocBuilder<AvailableTimesCubit, AvailableTimesState>(
                        builder: (context, state) {
                          final availableTimesByDay =
                              <int, DoctorAvailableTime>{
                                for (final item in state.times)
                                  item.dayOfWeek: item,
                              };

                          if (state.isLoading && !state.hasLoaded) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          return Column(
                            children: [
                              ..._dayOrder.map((dayOfWeek) {
                                final source =
                                    availableTimesByDay[dayOfWeek] ??
                                    DoctorAvailableTime(
                                      dayOfWeek: dayOfWeek,
                                      from: null,
                                      to: null,
                                      isOn: false,
                                    );
                                final workingDay = _toWorkingDay(source);

                                return WorkingHourRow(
                                  day: t(workingDay.day),
                                  workingDay: workingDay,
                                  isBusy: state.isSaving,
                                  onChanged: (newWorkingDay) {
                                    context
                                        .read<AvailableTimesCubit>()
                                        .updateWorkingDay(
                                          _toAvailableTime(newWorkingDay),
                                        );
                                  },
                                );
                              }),
                              if (state.errorMessage != null &&
                                  state.errorMessage!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    state.errorMessage!,
                                    style: TextStyle(
                                      color: cs.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              CustomButton(
                                text: state.isSaving
                                    ? t("Saving...")
                                    : t("Save Working Hours"),
                                onPressed: state.isSaving
                                    ? () {}
                                    : () async {
                                        final success = await context
                                            .read<AvailableTimesCubit>()
                                            .saveAvailableTimes();
                                        if (!mounted) return;

                                        if (success) {
                                          showSnackBar(
                                            context,
                                            t(
                                              "Working hours saved successfully!",
                                            ),
                                          );
                                          return;
                                        }

                                        final errorMessage = context
                                            .read<AvailableTimesCubit>()
                                            .state
                                            .errorMessage;
                                        showSnackBar(
                                          context,
                                          errorMessage?.trim().isNotEmpty ==
                                                  true
                                              ? errorMessage!
                                              : t(
                                                  "Failed to save working hours. Please try again.",
                                                ),
                                          isSuccess: false,
                                        );
                                      },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SettingsCard(
                      title: t("Delete Account"),
                      icon: Icons.warning_amber_rounded,
                      isDanger: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(
                              "This action is permanent and cannot be undone. Are you sure?",
                            ),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showDeleteAccountDialog,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(t("Delete Account")),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withOpacity(0.70)],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(
            theme.brightness == Brightness.dark ? 0.08 : 0.24,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Settings"),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr("Manage your application settings"),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _passwordDecoration(
    BuildContext context, {
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: cs.surfaceContainer.withOpacity(0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
      ),
    );
  }
}

// Custom Card Widget
class SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDanger;

  const SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final accent = isDanger ? cs.error : cs.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDanger ? cs.error.withOpacity(0.25) : cs.outlineVariant,
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDanger
                  ? cs.errorContainer.withOpacity(0.18)
                  : cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(22), child: child),
        ],
      ),
    );
  }
}

// Label Widget
class Label extends StatelessWidget {
  final String text;

  const Label({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }
}

// Custom Button
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(text),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: cs.outline),
        ),
        child: Text(text),
      ),
    );
  }
}

class ThemeModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const ThemeModeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.10)
              : theme.colorScheme.surfaceContainer.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeStyleChoice extends StatelessWidget {
  const _ThemeStyleChoice({
    required this.themeKey,
    required this.label,
    required this.color,
  });

  final String themeKey;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final selectedThemeKey = context.watch<ThemeStyleCubit>().state;
    final isSelected = selectedThemeKey == themeKey;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.read<ThemeStyleCubit>().setThemeStyle(themeKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.14)
              : cs.surfaceContainer.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : cs.outline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              context.tr(label),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Working Hours Model
class WorkingDay {
  final int dayOfWeek;
  final String day;
  String startTime;
  String endTime;
  bool enabled;

  WorkingDay({
    required this.dayOfWeek,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.enabled,
  });

  WorkingDay copyWith({String? startTime, String? endTime, bool? enabled}) {
    return WorkingDay(
      dayOfWeek: dayOfWeek,
      day: day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      enabled: enabled ?? this.enabled,
    );
  }
}

// Working Hour Row Widget
class WorkingHourRow extends StatelessWidget {
  final String day;
  final WorkingDay workingDay;
  final bool isBusy;
  final Function(WorkingDay) onChanged;

  const WorkingHourRow({
    super.key,
    required this.day,
    required this.workingDay,
    this.isBusy = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: workingDay.enabled
            ? cs.surfaceContainer.withOpacity(0.35)
            : cs.surfaceContainerHigh.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          final title = Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(
                    workingDay.enabled ? 0.12 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: workingDay.enabled ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Switch(
                value: workingDay.enabled,
                onChanged: isBusy
                    ? null
                    : (value) {
                        onChanged(workingDay.copyWith(enabled: value));
                      },
                activeColor: cs.primary,
              ),
            ],
          );

          final timeFields = Row(
            children: [
              Expanded(
                child: TimePickerField(
                  initialTime: workingDay.startTime,
                  enabled: workingDay.enabled && !isBusy,
                  onChanged: (time) {
                    onChanged(workingDay.copyWith(startTime: time));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr("to"),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TimePickerField(
                  initialTime: workingDay.endTime,
                  enabled: workingDay.enabled && !isBusy,
                  onChanged: (time) {
                    onChanged(workingDay.copyWith(endTime: time));
                  },
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [title, const SizedBox(height: 12), timeFields],
            );
          }

          return Row(
            children: [
              Flexible(
                flex: 3,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: title,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(flex: 4, child: timeFields),
            ],
          );
        },
      ),
    );
  }
}

// Time Picker Field Widget
class TimePickerField extends StatelessWidget {
  final String initialTime;
  final bool enabled;
  final Function(String) onChanged;

  const TimePickerField({
    super.key,
    required this.initialTime,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled
          ? () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _parseTime(initialTime),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(
                        context,
                      ).colorScheme.copyWith(primary: cs.primary),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                final formattedTime = _formatTime(picked);
                onChanged(formattedTime);
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? cs.surface : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: enabled ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              initialTime,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: enabled ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
