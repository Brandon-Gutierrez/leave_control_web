import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/presentation/admin_login_page.dart';
import '../../auth/state/session_controller.dart';
import '../../premises/models/premise.dart';
import '../data/qr_service.dart';
import '../models/qr_token.dart';
import '../models/season.dart';
import 'manual_entry_dialog.dart';
import 'qr_screen.dart';
import 'season_qr.dart';

/// Pantalla con el código QR de un predio.
///
/// Dos modos:
///  * Administrador ([QrGeneratorPage.new]): se llega desde el panel y se puede volver.
///  * Responsable de predio ([QrGeneratorPage.forPremiseManager]): es la única pantalla
///    de su cuenta. No tiene botón de volver ni de cerrar sesión, no reacciona
///    al botón "atrás" y el QR siempre es el del predio asignado en el servidor.
///
/// El aspecto lo pone [QrScreen]; en las fiestas de fin de año se viste de
/// fiesta (ver [Season]).
class QrGeneratorPage extends StatefulWidget {
  final Premise premise;
  final bool showNavigation;

  /// Fuerza una temporada (pruebas y vistas previas); por defecto, la de hoy.
  final Season? season;

  /// Crea la pantalla QR para administración.
  const QrGeneratorPage({super.key, required this.premise, this.season})
    : showNavigation = true;

  /// Crea la pantalla QR para el responsable del predio.
  QrGeneratorPage.forPremiseManager({
    super.key,
    required int premiseId,
    required String premiseName,
    this.season,
  }) : premise = Premise(id: premiseId, name: premiseName, reasonNames: []),
       showNavigation = false;

  /// Crea el estado de la pantalla QR.
  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

/// Gestiona la carga, caducidad y presentación del QR.
class _QrGeneratorPageState extends State<QrGeneratorPage> {
  /// Cada cuánto se reintenta sola la pantalla del responsable si falla.
  static const Duration _managerRetryDelay = Duration(seconds: 10);

  final QrService _qrService = QrService();
  final _qrKey = GlobalKey<SeasonQrState>();

  String? _qrToken;
  String? _premiseName;
  DateTime? _expiresAt;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  Timer? _retryTimer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  /// La temporada de la fecha de hoy; se vuelve a mirar con cada código nuevo
  /// (la pantalla puede quedar encendida días enteros).
  Season _todaySeason = Season.at(DateTime.now());

  bool get _isManager => !widget.showNavigation;
  Season get _season => widget.season ?? _todaySeason;

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
      _applyQr(await _qrService.createQrToken());
    } on ApiException catch (e) {
      _handleFetchError(e);
    }
  }

  /// Muestra el código nuevo y arranca la cuenta regresiva desde ese momento.
  void _applyQr(QrToken qr) {
    if (!mounted) return;
    setState(() {
      _qrToken = qr.token;
      _premiseName = qr.premiseName ?? _premiseName;
      _expiresAt = _deadlineOf(qr);
      _secondsRemaining = qr.ttl;
      _totalSeconds = qr.ttl;
      _isLoading = false;
      _errorMessage = null;
      _todaySeason = Season.at(DateTime.now());
    });
    _startAutoRefreshTimer();
  }

  void _handleFetchError(ApiException e) {
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

  /// El código venció. En temporada festiva el QR se deshace en el árbol, el
  /// código nuevo se pide con el árbol a la vista y el contador arranca cuando
  /// aparece el QR nuevo; si no, se pide directo.
  Future<void> _renewQr() async {
    final seasonQr = _qrKey.currentState;
    if (!_season.isFestive || _qrToken == null || seasonQr == null) {
      await _fetchQrToken();
      return;
    }
    _timer?.cancel();
    _retryTimer?.cancel();
    try {
      final qr = await seasonQr.renew<QrToken>(
        fetch: _qrService.createQrToken,
        tokenOf: (qr) => qr.token,
      );
      if (qr != null) _applyQr(qr);
    } on ApiException catch (e) {
      _handleFetchError(e);
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
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      (_) => false,
    );
  }

  /// Calcula los segundos restantes hasta la caducidad.
  int _remainingSeconds(DateTime expiresAt) {
    // Hacia arriba: con 59,2 s por delante se ve 1:00 → 0:59, sin saltos.
    final ms = expiresAt.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  /// Cuándo vence lo que se ve. Cuenta desde que el QR aparece en pantalla (con
  /// la animación de fiestas el código se pide unos segundos antes de
  /// mostrarse), para que el contador arranque completo. El servidor sigue
  /// aceptando el código unos segundos después de vencer, así que se limita a
  /// ese margen.
  DateTime _deadlineOf(QrToken qr) {
    final shown = DateTime.now().add(Duration(seconds: qr.ttl));
    final latest = qr.expiresAt.add(const Duration(seconds: 20));
    return shown.isBefore(latest) ? shown : latest;
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
        _renewQr();
      }
    });
  }

  /// Abre el registro manual; al terminar se vuelve solo al QR.
  Future<void> _openManualEntry() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ManualEntryDialog(),
    );
  }

  /// Construye la pantalla QR adaptable.
  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: widget.showNavigation
          ? AppBar(
              leading: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text(
                'Código QR',
                style: AppText.sectionTitle.copyWith(color: Colors.white),
              ),
              centerTitle: true,
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF121212),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Colors.white24)),
            )
          : null,
      body: QrScreen(
        premiseName: _premiseName ?? widget.premise.name,
        token: _qrToken,
        loading: _isLoading,
        errorMessage: _errorMessage,
        secondsRemaining: _secondsRemaining,
        totalSeconds: _totalSeconds,
        season: _season,
        isManager: _isManager,
        onRetry: _fetchQrToken,
        onManualEntry: _isManager ? _openManualEntry : null,
        qrKey: _qrKey,
      ),
    );

    // El responsable no puede salir de esta pantalla: "atrás" no hace nada.
    return _isManager ? PopScope(canPop: false, child: scaffold) : scaffold;
  }
}
