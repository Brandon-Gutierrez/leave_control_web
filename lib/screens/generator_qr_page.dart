import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
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
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= Breakpoints.tablet
                ? 32.0
                : 16.0;
            final cardWidth = (constraints.maxWidth - horizontalPadding * 2)
                .clamp(0.0, 720.0);
            final qrSize = [
              380.0,
              cardWidth - 64 - 24,
              constraints.maxHeight * 0.52,
            ].reduce((a, b) => a < b ? a : b).clamp(160.0, 380.0);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  24,
                ),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primaryRed,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Código de acceso',
                        style: AppText.heading.copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBg,
                          borderRadius:
                              BorderRadius.circular(AppDimens.fieldRadius),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.apartment_rounded,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Predio', style: AppText.caption),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.premise.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.cardTitle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Escanee este código con la aplicación móvil',
                        style: AppText.body.copyWith(color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        SizedBox(
                          height: qrSize,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryRed,
                            ),
                          ),
                        )
                      else if (_errorMessage != null)
                        _buildErrorState()
                      else if (_qrToken != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _qrToken!,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Se actualiza en: $_secondsRemaining s',
                                style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
