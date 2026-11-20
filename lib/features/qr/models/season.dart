/// Temporada del año que cambia el aspecto de la pantalla del responsable.
enum Season {
  /// El resto del año: fondo oscuro liso y el QR sin animación.
  none,

  /// Fiestas de fin de año: nieve, luces y el QR que se vuelve árbol.
  christmas;

  /// La temporada que corresponde a [date]. La navideña va del 1 de diciembre
  /// al 6 de enero (inclusive).
  static Season at(DateTime date) {
    final festive = date.month == 11 || (date.month == 1 && date.day <= 6);
    return festive ? Season.christmas : Season.none;
  }

  bool get isFestive => this != Season.none;
}
