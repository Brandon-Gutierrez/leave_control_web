import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Permite a administración cambiar cuántos segundos dura visible el código
/// QR antes de vencer.
class QrSettingsDialog extends StatefulWidget {
  final SettingsService? service;

  const QrSettingsDialog({super.key, this.service});

  @override
  State<QrSettingsDialog> createState() => _QrSettingsDialogState();
}

class _QrSettingsDialogState extends State<QrSettingsDialog> {
  static const primaryRed = AppColors.primaryRed;

  late final SettingsService _service = widget.service ?? SettingsService();
  final _controller = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  int _min = 30;
  int _max = 3600;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 480 ? width - 32 : 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tiempo de vida del QR', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(
                'Segundos que el código QR permanece visible y válido antes de '
                'vencer. Se aplica a los códigos generados desde ahora.',
                style: AppText.caption,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: primaryRed),
                  ),
                )
              else
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Segundos',
                    helperText: 'Entre $_min y $_max segundos.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: primaryRed, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isSaving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
