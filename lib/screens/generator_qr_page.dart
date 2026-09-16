import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';

class QrPage extends StatefulWidget {
  final Premise premise;
  const QrPage({super.key, required this.premise});

  @override
  State<QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<QrPage> {
  final PremiseService _premiseService = PremiseService();

  String? _qrToken;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _fetchQrToken();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al salir de la pantalla
    super.dispose();
  }

  Future<void> _fetchQrToken() async {
    _timer?.cancel(); // Reinicia cualquier temporizador activo

    setState(() {
      // Solo se muestra el indicador de carga si aún no hay un QR visible
      _isLoading = _qrToken == null;
      _errorMessage = null;
    });

    try {
      final qr = await _premiseService.createQrToken(widget.premise.id);
      if (!mounted) return;
      setState(() {
        _qrToken = qr.token;
        _secondsRemaining = qr.ttl;
        _isLoading = false;
      });
      _startAutoRefreshTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _qrToken = null;
        _errorMessage = e.statusCode != null
            ? 'Error en el servidor: ${e.statusCode}'
            : 'Error de conexión.';
        _isLoading = false;
      });
    }
  }

  void _startAutoRefreshTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        // Al llegar a 0, solicita un nuevo QR a Laravel
        _fetchQrToken();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.qrBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            // Medidas proporcionales al tamaño de la pantalla
            final outerMargin = screenWidth < 600 ? 16.0 : 32.0;
            final cardWidth = (screenWidth - outerMargin * 2).clamp(0.0, 800.0);
            final innerPadding = (cardWidth * 0.04).clamp(16.0, 32.0);
            final scale = (cardWidth / 800).clamp(0.45, 1.0);

            final titleSize = 50 * scale;
            final subtitleSize = (30 * scale).clamp(14.0, 30.0);
            final timerSize = (30 * scale).clamp(14.0, 30.0);

            // El QR ocupa lo que permita el ancho y la altura disponibles
            final qrSize = [
              480.0,
              cardWidth - innerPadding * 2,
              screenHeight * 0.55,
            ].reduce((a, b) => a < b ? a : b).clamp(160.0, 480.0);

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(outerMargin),
                    child: Container(
                      width: cardWidth, //ancho del recuadro
                      padding: EdgeInsets.all(innerPadding), //espacio interno
                      decoration: BoxDecoration(
                        color: Colors.white, //recuadro
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          //sombra del recuadro
                          BoxShadow(
                            color: AppColors.qrShadow,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, //ajusta el alto
                        children: [
                          Text(
                            'CONTROL DE SALIDAS TEMPORALES',
                            style: TextStyle(
                              color: AppColors.qrText,
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20 * scale),
                          Text(
                            widget.premise.name,
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            'Escanee el código con la aplicación móvil',
                            style: TextStyle(
                              color: AppColors.qrText,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 44 * scale),
                          if (_isLoading) ...[
                            SizedBox(
                              height: qrSize,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ] else if (_errorMessage != null) ...[
                            SizedBox(
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchQrToken,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_qrToken != null) ...[
                            QrImageView(
                              data: _qrToken!,
                              version: QrVersions.auto,
                              size: qrSize,
                              backgroundColor: Colors.white,
                            ),
                            SizedBox(height: 40 * scale),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: timerSize,
                                  color: AppColors.qrText,
                                ),
                                Text(
                                  'Se actualiza en: $_secondsRemaining s',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: timerSize,
                                    color: AppColors.qrText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Volver al panel
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
