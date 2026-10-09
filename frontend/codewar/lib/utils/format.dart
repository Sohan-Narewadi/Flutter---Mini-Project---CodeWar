/// 987 -> "987", 12345 -> "12.3K", 2500000 -> "2.5M". Keeps big numbers
/// short enough for chips and podiums.
String compactNumber(int n) {
  final neg = n < 0;
  final v = n.abs();
  String out;
  if (v < 10000) {
    out = '$v';
  } else if (v < 1000000) {
    out = '${_trim(v / 1000)}K';
  } else {
    out = '${_trim(v / 1000000)}M';
  }
  return neg ? '-$out' : out;
}

String _trim(double d) {
  final s = d.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
