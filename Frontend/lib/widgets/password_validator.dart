class PasswordValidator {
  const PasswordValidator._();

  static String? validateFormat(String password) {
    if (password.length < 12 || password.length > 128) {
      return 'Password must be 12 to 128 characters';
    }
    if (RegExp(r'\s').hasMatch(password)) {
      return 'Password must not contain spaces';
    }
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

    if (!hasLowercase || !hasUppercase || !hasNumber || !hasSymbol) {
      return 'Password must include a lowercase letter, uppercase letter, number, and symbol';
    }
    return null;
  }
}
