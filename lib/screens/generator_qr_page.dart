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

  const QrPage({super.key, required this.premise}) : showNavigation = true;

  QrPage.forPremiseManager({
    super.key,
    required int premiseId,
    required String premiseName,
  }) : premise = Premise(id: premiseId, name: premiseName, reasonNames: []),
       showNavigation = false;

  @override
  State<QrPage> createState() => _QrPageState();
}

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

  bool get _isManager => !widget.showNavigation;

  @override
  void initState() {
    super.initState();
    _fetchQrToken();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al salir de la pantalla
    _retryTimer?.cancel();
    super.dispose();
  }

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

  /// La sesión ya no es válida en el servidor (venció o administración la cerró).
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

  int _remainingSeconds(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

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

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.loginBg,
      appBar: widget.showNavigation
          ? AppBar(
              leading: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Código QR', style: AppText.sectionTitle),
              centerTitle: true,
              backgroundColor: AppColors.lightBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qrSize = [
              constraints.maxWidth - 64,
              constraints.maxHeight - 182,
            ].reduce((a, b) => a < b ? a : b).clamp(160.0, 900.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                      border: Border.all(
                        color: AppColors.qrBackground,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'rsc/comteco.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PREDIO: ${_premiseName ?? widget.premise.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        if (_qrToken != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Se actualiza en: $_secondsRemaining s',
                            style: AppText.cardTitle.copyWith(
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.primaryRed,
                            )
                          : _errorMessage != null
                          ? _buildErrorState()
                          : _qrToken == null
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.cardRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.primaryRed,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: _qrToken!,
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // El responsable no puede salir de esta pantalla: "atrás" no hace nada.
    return _isManager
        ? PopScope(canPop: false, child: scaffold)
        : scaffold;
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: AppText.body.copyWith(color: Colors.red.shade700),
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
