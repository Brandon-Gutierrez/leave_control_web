import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_modal.dart';
import '../widgets/dialog_header.dart';
import '../theme/app_text_styles.dart';

/// Permite a administración cambiar cuántos segundos dura visible el código
/// QR antes de vencer.
class QrSettingsDialog extends StatefulWidget {
  final SettingsService? service;

  /// Ejecuta la tarea.
  const QrSettingsDialog({super.key, this.service});

  /// Crea el estado del widget.
  @override
  State<QrSettingsDialog> createState() => _QrSettingsDialogState();
}

/// Representa esta entidad.
class _QrSettingsDialogState extends State<QrSettingsDialog> {

  late final SettingsService _service = widget.service ?? SettingsService();
  final _controller = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  int _min = 30;
  int _max = 3600;

  /// Inicializa el estado.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Libera los recursos.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ejecuta la tarea.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await _service.getQrSettings();
      if (!mounted) return;
      setState(() {
        _controller.text = settings.ttlSeconds.toString();
        _min = settings.minSeconds;
        _max = settings.maxSeconds;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  /// Ejecuta la tarea.
  Future<void> _save() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < _min || value > _max) {
      setState(() => _error = 'Ingrese un valor entre $_min y $_max segundos.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _service.updateQrTtl(value);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSaving = false;
      });
    }
  }

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: DialogTone.configure,
      icon: Icons.timer_rounded,
      title: 'Tiempo de vida del QR',
      subtitle: 'Cuánto dura visible el código antes de cambiar',
      maxWidth: 460,
      actions: [
        ModalButton(
          label: 'Cancelar',
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
        ),
        ModalButton(
          label: 'Guardar',
          primary: true,
          color: AppColors.info,
          isLoading: _isSaving,
          onPressed: _isLoading ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Es el tiempo que el código QR permanece válido antes de vencer. '
            'Se aplica a los códigos que se generen desde ahora.',
            style: AppText.body,
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.info),
              ),
            )
          else
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Segundos',
                helperText: 'Entre $_min y $_max segundos.',
                suffixText: 'segundos',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorLine(_error!),
          ],
        ],
      ),
    );
  }
}

/// Representa esta entidad.
class _ErrorLine extends StatelessWidget {
  final String message;

  /// Ejecuta la tarea.
  const _ErrorLine(this.message);

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.dangerBg,
        border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
