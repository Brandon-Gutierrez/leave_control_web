import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/date_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_field.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/settings_service.dart';
import '../models/qr_settings.dart';
import 'settings_card.dart';

/// Vida del código QR: cuántos segundos dura visible antes de renovarse. Se
/// edita sobre un borrador que se guarda (o se descarta) con los botones del
/// pie; el cambio vale para los códigos que se generen desde ese momento.
class QrSettingsCard extends StatefulWidget {
  final SettingsService? service;

  const QrSettingsCard({super.key, this.service});

  @override
  State<QrSettingsCard> createState() => _QrSettingsCardState();
}

class _QrSettingsCardState extends State<QrSettingsCard> {
  final AdminDataStore _store = AdminDataStore.instance;
  late final SettingsService _service = widget.service ?? SettingsService();
  final _controller = TextEditingController();

  /// Lo último que se leyó o guardó; el borrador se compara con esto.
  QrSettings? _source;
  bool _saving = false;
  String? _error;

  StoreResource<QrSettings?> get _data => _store.qrSettingsData;
  int get _min => _source?.minSeconds ?? 30;
  int get _max => _source?.maxSeconds ?? 3600;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _adoptStoreValue();
    unawaited(_data.load());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(_adoptStoreValue);
  }

  /// Toma el valor del servidor si llegó uno nuevo y no hay nada escrito a
  /// medias (con cambios sin guardar se respetan).
  void _adoptStoreValue() {
    final value = _data.value;
    if (value == null || identical(value, _source) || _dirty) return;
    _source = value;
    _controller.text = value.ttlSeconds.toString();
  }

  int? get _value => int.tryParse(_controller.text.trim());

  bool get _valid {
    final v = _value;
    return v != null && v >= _min && v <= _max;
  }

  bool get _dirty {
    final source = _source;
    return source != null &&
        _controller.text.trim() != source.ttlSeconds.toString();
  }

  void _cancel() => setState(() {
    _controller.text = _source?.ttlSeconds.toString() ?? '';
    _error = null;
  });

  Future<void> _save() async {
    final value = _value;
    final source = _source;
    if (_saving || !_valid || value == null || source == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateQrTtl(value);
      if (!mounted) return;
      setState(() {
        _source = QrSettings(
          ttlSeconds: value,
          minSeconds: source.minSeconds,
          maxSeconds: source.maxSeconds,
        );
        _saving = false;
      });
      showAppPopup(
        context,
        'Vida del código QR actualizada a ${DateText.seconds(value)}',
      );
      // Inicio muestra esta regla: se vuelve a leer.
      unawaited(_store.refreshQuietly());
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return;
      }
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final loading = _source == null && data.isInitialLoad;
    final failed = _source == null && data.hasFailed;
    final value = _value;

    final Widget body;
    if (loading) {
      body = const SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 48, radius: 8),
            SizedBox(height: 18),
            SkeletonBox(height: 96, radius: 6),
          ],
        ),
      );
    } else if (failed) {
      body = LoadErrorNotice(
        message: data.error ?? 'No se pudo cargar la configuración del QR',
        onRetry: () => data.load(force: true),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsField(
            label: 'Segundos ($_min a $_max)',
            hint: 'Se aplica a los códigos que se generen desde ahora.',
            child: TextField(
              key: const ValueKey('qr-seconds'),
              controller: _controller,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              decoration: adminFieldDecoration(
                suffixText: 'segundos',
                errorText: _dirty && !_valid
                    ? 'Ingresa un valor entre $_min y $_max segundos.'
                    : null,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Equivale a',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  _valid && value != null ? DateText.seconds(value) : '—',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'El QR se renueva solo antes de vencer y se mantiene 30 s '
                  'más para quien ya lo escaneó.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
          if (_error != null) SettingsErrorNote(_error!),
        ],
      );
    }

    return SettingsCard(
      icon: Icons.qr_code_2_rounded,
      title: 'Vida del código QR',
      subtitle: 'Cada cuánto cambia el QR del predio',
      footer: loading || failed
          ? null
          : SettingsFooter(
              dirty: _dirty,
              valid: _valid,
              saving: _saving,
              onCancel: _cancel,
              onSave: _save,
            ),
      children: [body],
    );
  }
}
