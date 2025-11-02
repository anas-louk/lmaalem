/// Extensions pour les String
extension StringExtensions on String {
  /// Capitaliser la première lettre
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitaliser chaque mot
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  /// Vérifier si c'est un email valide
  bool isValidEmail() {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Vérifier si c'est un numéro de téléphone valide
  bool isValidPhone() {
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    return phoneRegex.hasMatch(replaceAll(RegExp(r'[\s-]'), ''));
  }
}

