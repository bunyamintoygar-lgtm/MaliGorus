class NameFormatter {
  /// Formats a full name to "FirstName L." format.
  /// Example: "Ahmet Can Toygar" -> "Ahmet T."
  /// Example: "Ahmet Toygar" -> "Ahmet T."
  static String format(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'Kullanıcı';
    
    final trimmedName = fullName.trim();
    final parts = trimmedName.split(RegExp(r'\s+'));
    
    if (parts.length < 2) return trimmedName;
    
    final firstName = parts.first;
    final lastPart = parts.last;
    
    if (lastPart.isEmpty) return firstName;
    
    final lastNameInitial = lastPart[0].toUpperCase();
    return '$firstName $lastNameInitial.';
  }
}
