import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../models/season.dart';
import 'festive_backdrop.dart';
import 'season_qr.dart';

/// «5:00», «10:42»: lo que falta para que el código se renueve.
String formatClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}

/// La pantalla fija del responsable, a pantalla completa: a un lado el predio
/// y los tres pasos para registrar una salida, al otro el QR grande en un
/// panel blanco. En temporada festiva se viste de fiesta (ver [Season]).
///
/// Solo dibuja: el QR y la cuenta regresiva los manda quien la usa.
class QrScreen extends StatelessWidget {
  final String premiseName;

  /// Lo que codifica el QR; null mientras no hay uno.
  final String? token;
  final bool loading;
  final String? errorMessage;
  final int secondsRemaining;
  final int totalSeconds;
  final Season season;

  /// Cuenta del responsable: hay botón de registro manual y el error se
  /// reintenta solo.
  final bool isManager;
  final VoidCallback onRetry;
  final VoidCallback? onManualEntry;

  /// Para renovar el código con la animación (ver [SeasonQrState.renew]).
  final GlobalKey<SeasonQrState>? qrKey;

  const QrScreen({
    super.key,
    required this.premiseName,
    required this.token,
    required this.loading,
    required this.errorMessage,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.season,
    required this.isManager,
    required this.onRetry,
    this.onManualEntry,
    this.qrKey,
  });

  static const _steps = [
    'Abra la app Salidas Temporales',
    'Escanee el código',
    'Elija su motivo si va a salir',
  ];

  bool get _festive => season.isFestive;

  Color get _muted =>
      _festive ? const Color(0xFF9FB6A8) : const Color(0xFFA3A3A3);

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, box) =>
          box.maxWidth >= 900 ? _wide(context, box) : _narrow(context, box),
    );
    return _festive
        ? FestiveBackdrop(child: body)
        : ColoredBox(color: const Color(0xFF121212), child: body);
  }

  // -------------------------------------------------------------------------
  // Pantalla ancha (la del monitor del responsable)
  // -------------------------------------------------------------------------

  Widget _wide(BuildContext context, BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    // Todo se escala con la ventana: el diseño base es de 1280 x 800.
    final s = math.min(h / 800, w / 1280).clamp(0.6, 1.8);
    double u(double v) => v * s;

    final left = u(48);
    final column = u(420);
    final gap = u(32);
    final edge = u(20);
    final side = math
        .min(h - 2 * edge, w - left - column - gap - edge)
        .clamp(240.0, 4000.0);

    return Row(
      children: [
        SizedBox(width: left),
        SizedBox(
          width: column,
          child: Center(child: SingleChildScrollView(child: _info(context, s))),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: edge),
              child: _qrPanel(context, side, s),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Pantalla angosta (tableta o teléfono)
  // -------------------------------------------------------------------------

  Widget _narrow(BuildContext context, BoxConstraints box) {
    const s = 0.7;
    final side = math.min(box.maxWidth - 32, 560.0).clamp(200.0, 560.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_festive)
                  Align(alignment: Alignment.centerLeft, child: _badge(s)),
                if (_festive) const SizedBox(height: 14),
                _brand(s),
                const SizedBox(height: 20),
                Center(child: _qrPanel(context, side, s)),
                const SizedBox(height: 22),
                _stepsList(s),
                if (isManager) ...[
                  const SizedBox(height: 20),
                  _manualButton(s),
                ],
                if (token != null) ...[const SizedBox(height: 22), _clock(s)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Piezas
  // -------------------------------------------------------------------------

  /// El texto de la izquierda (pantalla ancha).
  Widget _info(BuildContext context, double s) {
    double u(double v) => v * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_festive) ...[_badge(s), SizedBox(height: u(24))],
        _brand(s),
        SizedBox(height: u(24)),
        Text(
          'Registre su salida o retorno',
          style: TextStyle(
            fontSize: u(36),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.12,
            color: Colors.white,
          ),
        ),
        SizedBox(height: u(24)),
        _stepsList(s),
        if (isManager) ...[SizedBox(height: u(24)), _manualButton(s)],
        if (token != null) ...[SizedBox(height: u(24)), _clock(s)],
      ],
    );
  }

  Widget _badge(double s) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 7 * s),
    decoration: BoxDecoration(
      color: AppColors.primaryRed,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '¡Felices fiestas!',
      style: TextStyle(
        fontSize: 14 * s,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
    ),
  );

  /// El logo y el nombre del predio.
  Widget _brand(double s) => Row(
    children: [
      Container(
        width: 72 * s,
        height: 72 * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * s),
        ),
        child: AppLogo(size: 60 * s),
      ),
      SizedBox(width: 14 * s),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREDIO',
              style: TextStyle(
                fontSize: 13 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: _muted,
              ),
            ),
            Text(
              premiseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 34 * s,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _stepsList(double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < _steps.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 14 * s),
          child: Row(
            children: [
              Container(
                width: 38 * s,
                height: 38 * s,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 14 * s),
              Expanded(
                child: Text(
                  _steps[i],
                  style: TextStyle(
                    fontSize: 19 * s,
                    fontWeight: FontWeight.w600,
                    color: _festive
                        ? const Color(0xFFE8F0EA)
                        : const Color(0xFFEDEDED),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// Para quien no puede escanear: ingresa con item y carnet.
  Widget _manualButton(double s) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: onManualEntry,
      icon: Icon(Icons.badge_outlined, size: 22 * s, color: Colors.white),
      label: const Text('Registro manual'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        minimumSize: Size(0, 56 * s),
        padding: EdgeInsets.symmetric(horizontal: 24 * s),
        side: const BorderSide(color: Colors.white, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 17 * s,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  /// «El código se renueva solo», lo que falta y la barra que se vacía.
  Widget _clock(double s) {
    final progress = totalSeconds > 0
        ? (secondsRemaining / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'El código se renueva solo',
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ),
            Text(
              formatClock(secondsRemaining),
              key: const ValueKey('qr-clock'),
              style: TextStyle(
                fontSize: 20 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * s),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 8 * s,
            color: _festive ? const Color(0xFF233229) : const Color(0xFF2A2A2A),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE04B4B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// El panel blanco con el QR (o la carga, o el error).
  Widget _qrPanel(BuildContext context, double side, double s) {
    final padding = math.max(16.0, 48 * s);
    final inner = math.max(120.0, side - 2 * padding);
    final Widget content;
    if (loading) {
      content = const CircularProgressIndicator(color: AppColors.primaryRed);
    } else if (errorMessage != null) {
      content = _error();
    } else if (token == null) {
      content = const SizedBox.shrink();
    } else {
      content = SeasonQr(key: qrKey, data: token!, size: inner);
    }
    return Container(
      width: side,
      height: side,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(math.max(12, 32 * s)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            spreadRadius: 8 * s,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 80 * s,
            offset: Offset(0, 30 * s),
          ),
        ],
      ),
      child: Center(child: content),
    );
  }

  Widget _error() => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey.shade600),
        const SizedBox(height: 12),
        Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isManager) ...[
          const SizedBox(height: 6),
          Text(
            'Se reintentará automáticamente.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, AppDimens.smallButtonHeight),
          ),
        ),
      ],
    ),
  );
}
