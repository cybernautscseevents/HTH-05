/// Converts accidental model Markdown into clean plain text for patients.
/// The API requests plain text; this is a defensive fallback if the model
/// still returns formatting markers or repeats the source footer.
String cleanPatientFacingText(String input, {bool forSpeech = false}) {
  final lines = <String>[];
  for (final rawLine in input.split('\n')) {
    if (RegExp(
      r'^\s*(source|sources|filename|document source)\s*:',
      caseSensitive: false,
    ).hasMatch(rawLine)) {
      continue;
    }
    var line = rawLine.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );
    line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ');
    line = line.replaceAll(
      RegExp(r'```?|\*\*|__|~~|(?<!\w)\*(?!\w)|(?<!\w)_(?!\w)'),
      '',
    );
    if (RegExp(r'^\s*(---|\*\*\*|___)\s*$').hasMatch(line)) continue;
    lines.add(line.trimRight());
  }
  var result = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (forSpeech) result = result.replaceAll('• ', '').replaceAll('•', '');
  return result;
}

/// Keep a useful report identity without letting an uploaded filename dominate
/// the chat bubble footer.
String conciseReportSource(String source, {int maxLength = 42}) {
  final value = source.trim();
  if (value.length <= maxLength) return value;
  final dot = value.lastIndexOf('.');
  final extension = dot > value.lastIndexOf('/') && value.length - dot <= 8
      ? value.substring(dot)
      : '';
  final prefixLength = maxLength - extension.length - 1;
  return '${value.substring(0, prefixLength.clamp(1, value.length).toInt())}…$extension';
}
