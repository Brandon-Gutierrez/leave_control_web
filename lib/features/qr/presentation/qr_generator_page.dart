import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../session/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'login_admin_page.dart';

/// Pantalla con el código QR de un predio.
///
/// Dos modos:
///  * Administrador ([QrPage.new]): se llega desde el panel y se puede volver.
///  * Responsable de predio ([QrPage.forPremiseManager]): es la única pantalla
///    de su cuenta. No tiene botón de volver ni de cerrar sesión, no reacciona
///    al botón "atrás" y el QR siempre es el del predio asignado en el servidor.
class QrPage extends StatefulWidget {
  final Premise premise;
  final bool showNavigation;

  /// Crea la pantalla QR para administración.
  const QrPage({super.key, required this.premise}) : showNavigation = true;

  /// Crea la pantalla QR para el responsable del predio.
  QrPage.forPremiseManager({
    super.key,
    required int premiseId,
    required String premiseName,
  }) : premise = Premise(id: premiseId, name: premiseName, reasonNames: []),
       showNavigation = false;

  /// Crea el estado de la pantalla QR.
  @override
  State<QrPage> createState() => _QrPageState();
}

/// Gestiona la carga, caducidad y presentación del QR.
class _QrPageState extends State<QrPage> {
  /// Cada cuánto se reintenta sola la pantalla del responsable si falla.
  static const Duration _managerRetryDelay = Duration(seconds: 10);

  final PremiseService _premiseService = PremiseService();

  String? _qrToken;
  String? _premiseName;
  DateTime? _expiresAt;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  Timer? _retryTimer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  bool get _isManager => !widget.showNavigation;

  /// Inicializa la pantalla y solicita un QR.
  @override
  void initState() {
    super.initState();
    _fetchQrToken();
  }

  /// Cancela temporizadores al cerrar la pantalla.
  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al salir de la pantalla
    _retryTimer?.cancel();
    super.dispose();
  }

  /// Solicita un QR y prepara su renovación.
  Future<void> _fetchQrToken() async {
    _timer?.cancel(); // Reinicia cualquier temporizador activo
    _retryTimer?.cancel();

    setState(() {
      // Solo se muestra el indicador de carga si aún no hay un QR visible
      _isLoading = _qrToken == null;
      _errorMessage = null;
    });

    try {
      final qr = await _premiseService.createQrToken();
      if (!mounted) return;
      setState(() {
        _qrToken = qr.token;
        _premiseName = qr.premiseName ?? _premiseName;
        _expiresAt = qr.expiresAt;
        _secondsRemaining = qr.ttl;
        _totalSeconds = qr.ttl;
        _isLoading = false;
      });
      _startAutoRefreshTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        _handleSessionLost();
        return;
      }
      setState(() {
        _qrToken = null;
        _expiresAt = null;
        _errorMessage = e.message;
        _isLoading = false;
      });
      // La pantalla del responsable queda encendida sin nadie que toque el
      // botón: se recupera sola cuando vuelve la conexión.
      if (_isManager) {
        _retryTimer = Timer(_managerRetryDelay, _fetchQrToken);
      }
    }
  }

  /// Gestiona una sesión vencida o cerrada.
  void _handleSessionLost() {
    if (_isManager) {
      // Se limpia la sesión: la raíz de la app vuelve al inicio de sesión.
      SessionController.instance.clear();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginAdminPage()),
      (_) => false,
    );
  }

  /// Calcula los segundos restantes hasta la caducidad.
  int _remainingSeconds(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// Actualiza la cuenta regresiva y renueva el QR.
  void _startAutoRefreshTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final expiresAt = _expiresAt;
      if (expiresAt == null) {
        timer.cancel();
        return;
      }
      final remaining = _remainingSeconds(expiresAt);
      if (remaining > 0) {
        if (mounted) setState(() => _secondsRemaining = remaining);
      } else {
        timer.cancel();
        _fetchQrToken();
      }
    });
  }

  /// Elige el color según el tiempo restante.
  Color get _timeColor {
    if (_totalSeconds <= 0) return AppColors.success;
    final ratio = _secondsRemaining / _totalSeconds;
    if (ratio > 0.5) return AppColors.success;
    if (ratio > 0.2) return AppColors.warning;
    return AppColors.danger;
  }


  /// Construye la pantalla QR adaptable.
  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showNavigation
          ? AppBar(
              leading: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Código QR', style: AppText.sectionTitle),
              centerTitle: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final name = _premiseName ?? widget.premise.name;

          if (wide) {
            final panelWidth = (constraints.maxWidth * 0.36).clamp(380.0, 640.0);
            return Row(
              children: [
                SizedBox(width: panelWidth, child: _buildBrandPanel(name, wide: true)),
                Expanded(child: _buildQrArea(constraints, wide: true, panelWidth: panelWidth)),
              ],
            );
          }
          return SafeArea(
            child: Column(
              children: [
                _buildBrandPanel(name, wide: false),
                Expanded(child: _buildQrArea(constraints, wide: false, panelWidth: 0)),
              ],
            ),
          );
        },
      ),
    );

    // El responsable no puede salir de esta pantalla: "atrás" no hace nada.
    return _isManager
        ? PopScope(canPop: false, child: scaffold)
        : scaffold;
  }

  /// Muestra el nombre del predio y las instrucciones.
  Widget _buildBrandPanel(String name, {required bool wide}) {
    // En pantallas bajas (laptop) todo se compacta para que nada se corte.
    final compact = MediaQuery.sizeOf(context).height < 860;
    final progress = _totalSeconds > 0
        ? (_secondsRemaining / _totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final pad = wide ? (compact ? 32.0 : 48.0) : 20.0;

    const steps = [
      'Abra la aplicación móvil',
      'Toque «Registrar mi salida» o «mi retorno»',
      'Apunte la cámara a este código',
    ];

    return Container(
      color: AppColors.primaryRed,
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Image.asset(
              'rsc/comteco.png',
              height: wide ? 40 : 30,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.apartment_rounded),
            ),
          ),
          SizedBox(height: wide ? (compact ? 28 : 48) : 14),
          const Text(
            'PREDIO',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 3,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? (compact ? 42 : 56) : 30,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          if (wide) ...[
            SizedBox(height: compact ? 24 : 40),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 12 : 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      color: Colors.white,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
          ] else
            const SizedBox(height: 14),
          if (_qrToken != null) ...[
            Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Se actualiza en: $_secondsRemaining s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 30 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: wide ? 14 : 10,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ],
        ],
      ),
    );
  }

  /// Muestra el QR, la carga o el error.
  Widget _buildQrArea(BoxConstraints constraints, {required bool wide, required double panelWidth}) {
    final color = _timeColor;
    final frame = wide ? 64.0 + 24 : 40.0 + 16;

    return LayoutBuilder(builder: (context, box) {
    final qrSize = [box.maxWidth - frame, box.maxHeight - frame]
        .reduce((a, b) => a < b ? a : b)
        .clamp(120.0, 1100.0);
    return Container(
      color: const Color(0xFFF4F4F4),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: AppColors.primaryRed)
            : _errorMessage != null
            ? _buildErrorState()
            : _qrToken == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(wide ? 20 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: color, width: wide ? 12 : 8),
                    ),
                    child: QrImageView(
                      data: _qrToken!,
                      version: QrVersions.auto,
                      size: qrSize,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
    });
  }

  /// Muestra el error y permite reintentar.
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: AppText.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (_isManager) ...[
            const SizedBox(height: 6),
            Text(
              'Se reintentará automáticamente.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchQrToken,
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
}
