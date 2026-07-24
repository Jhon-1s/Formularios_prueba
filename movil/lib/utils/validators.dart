class Validators {
  // ============================================================
  // VALIDAR EMAIL
  // ============================================================
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo es obligatorio';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Correo inválido';
    }
    return null;
  }
  
  // ============================================================
  // VALIDAR CONTRASEÑA
  // ============================================================
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }
  
  // ============================================================
  // VALIDAR TELÉFONO
  // ============================================================
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opcional
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Teléfono inválido (10 dígitos)';
    }
    return null;
  }
  
  // ============================================================
  // VALIDAR CAMPO REQUERIDO
  // ============================================================
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Este campo'} es obligatorio';
    }
    return null;
  }
}