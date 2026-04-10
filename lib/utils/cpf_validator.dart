/// Utilitário para validação de CPF em Flutter.
/// Implementa a validação oficial do CPF brasileiro.
library;

String _cleanCPF(String cpf) {
  return cpf.replaceAll(RegExp(r'[^0-9]'), '');
}

bool isValidCPF(String cpf) {
  final cleaned = _cleanCPF(cpf);

  if (cleaned.length != 11) {
    return false;
  }

  if (RegExp(r'^(\d)\1*$').hasMatch(cleaned)) {
    return false;
  }

  int sum = 0;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(cleaned[i]) * (10 - i);
  }

  int firstCheck = (sum % 11 < 2) ? 0 : (11 - (sum % 11));
  if (firstCheck != int.parse(cleaned[9])) {
    return false;
  }

  sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(cleaned[i]) * (11 - i);
  }

  int secondCheck = (sum % 11 < 2) ? 0 : (11 - (sum % 11));
  return secondCheck == int.parse(cleaned[10]);
}

String formatCPF(String cpf) {
  final cleaned = _cleanCPF(cpf);
  if (cleaned.length != 11) {
    throw ArgumentError('CPF deve ter 11 dígitos');
  }
  return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9)}';
}