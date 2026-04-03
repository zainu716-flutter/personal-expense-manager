// ── Indian Number Format Mixin ────────────────
mixin IndianFormatMixin {
  String formatIndian(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final formatted = _indianFormat(absValue);
    return isNegative ? '-$formatted' : formatted;
  }

  String _indianFormat(double value) {
    final parts = value
        .toStringAsFixed(value == value.truncateToDouble() ? 0 : 2)
        .split('.');
    String intPart = parts[0];
    String decPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (decPart.isNotEmpty) {
      decPart = decPart.replaceAll(RegExp(r'0+$'), '');
      if (decPart == '.') decPart = '';
    }
    if (intPart.length <= 3) return '$intPart$decPart';
    String result = intPart.substring(intPart.length - 3);
    intPart = intPart.substring(0, intPart.length - 3);
    while (intPart.length > 2) {
      result = '${intPart.substring(intPart.length - 2)},$result';
      intPart = intPart.substring(0, intPart.length - 2);
    }
    if (intPart.isNotEmpty) result = '$intPart,$result';
    return '$result$decPart';
  }
}