/// El texto en minúsculas y sin tildes, para ordenar y buscar sin que importen
/// las mayúsculas ni los acentos.
String foldText(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final unit in lower.runes) {
    final char = String.fromCharCode(unit);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}

/// La inicial para agrupar una lista: sin tilde y en mayúscula; «#» si el
/// nombre no empieza con una letra.
String groupLetterOf(String name) {
  final folded = foldText(name).trim();
  if (folded.isEmpty) return '#';
  final first = folded[0].toUpperCase();
  return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
}
