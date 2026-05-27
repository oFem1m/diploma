String formatBestF(double value, {int maxPlainLength = 14}) {
  final absValue = value.abs();
  if (value != 0 && (absValue >= 1e12 || absValue < 1e-6)) {
    return value.toStringAsExponential(6);
  }

  for (var digits = 12; digits >= 0; digits--) {
    final text = _trimTrailingZeros(value.toStringAsFixed(digits));
    if (!text.contains('e') && text.length <= maxPlainLength) {
      return text;
    }
  }

  return value.toStringAsExponential(6);
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;
  var result = value;
  while (result.endsWith('0')) {
    result = result.substring(0, result.length - 1);
  }
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }
  if (result == '-0') return '0';
  return result;
}
