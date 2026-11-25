import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_field.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/master_detail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/settings_service.dart';
import '../models/leave_limits.dart';
import 'settings_card.dart';

/// Límites de salidas, iguales para todo el personal:
/// - por persona: cuántas salidas en total en un período;
/// - por motivo: cuántas veces puede elegir un mismo motivo, con un tope
///   general (el mismo para cada motivo) o uno personalizado por motivo.
///
/// Se edita sobre un borrador que se guarda (o se descarta) con los botones
/// del pie. Un tope vacío significa «sin tope»; el mínimo es 1.
class LeaveLimitsCard extends StatefulWidget {
  final SettingsService? service;

  const LeaveLimitsCard({super.key, this.service});

  @override
  State<LeaveLimitsCard> createState() => _LeaveLimitsCardState();
}

class _LeaveLimitsCardState extends State<LeaveLimitsCard> {
  static const _periodOptions = [
    ('day', 'Día'),
    ('week', 'Semana'),
    ('month', 'Mes'),
  ];

  final AdminDataStore _store = AdminDataStore.instance;
  late final SettingsService _service = widget.service ?? SettingsService();

  final _total = TextEditingController();
  final _general = TextEditingController();
  final Map<int, TextEditingController> _caps = {};

  /// Lo último que se leyó o guardó; el borrador se compara con esto.
  LeaveLimits? _source;
  List<ReasonCap> _reasons = [];
  String _period = 'day';
  String _reasonPeriod = 'day';
  String _mode = ReasonLimit.general;
  bool _saving = false;
  String? _error;

  StoreResource<LeaveLimits?> get _data => _store.leaveLimitsData;

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
    _total.dispose();
    _general.dispose();
    for (final c in _caps.values) {
      c.dispose();
    }
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
    _adopt(value);
  }

  /// Pone [limits] como lo guardado y el borrador igual a eso.
  void _adopt(LeaveLimits limits) {
    _source = limits;
    _period = limits.period;
    _total.text = limits.maxExits?.toString() ?? '';
    final reason = limits.reasonLimit;
    _reasonPeriod = reason.period;
    _mode = reason.mode;
    _general.text = reason.maxGeneral?.toString() ?? '';
    _reasons = reason.caps;
    for (final c in _caps.values) {
      c.dispose();
    }
    _caps
      ..clear()
      ..addEntries([
        for (final cap in _reasons)
          MapEntry(
            cap.reasonId,
            TextEditingController(text: cap.max?.toString() ?? ''),
          ),
      ]);
    _error = null;
  }

  /// Vacío = sin tope; 0 no es un tope válido.
  static ({bool valid, int? value}) _parse(String text) {
    final value = int.tryParse(text.trim());
    return (valid: value == null || value >= 1, value: value);
  }

  bool get _totalValid => _parse(_total.text).valid;
  bool get _generalValid => _parse(_general.text).valid;
  bool _capValid(ReasonCap cap) => _parse(_caps[cap.reasonId]!.text).valid;

  /// Los topes que se usan según el modo elegido son válidos.
  bool get _valid =>
      _totalValid &&
      (_mode == ReasonLimit.general
          ? _generalValid
          : _reasons.every(_capValid));

  /// El tope escrito; si es inválido (0), el último guardado, para que un
  /// campo que no se usa en el modo elegido nunca viaje al servidor.
  static int? _valueOrSaved(String text, int? saved) {
    final parsed = _parse(text);
    return parsed.valid ? parsed.value : saved;
  }

  /// Los límites tal como están escritos.
  LeaveLimits get _draft {
    final saved = _source!.reasonLimit;
    return LeaveLimits(
      period: _period,
      maxExits: _valueOrSaved(_total.text, _source!.maxExits),
      reasonLimit: ReasonLimit(
        period: _reasonPeriod,
        mode: _mode,
        maxGeneral: _valueOrSaved(_general.text, saved.maxGeneral),
        caps: [
          for (final cap in _reasons)
            ReasonCap(
              reasonId: cap.reasonId,
              name: cap.name,
              max: _valueOrSaved(_caps[cap.reasonId]!.text, cap.max),
            ),
        ],
      ),
    );
  }

  /// Hay algo distinto de lo guardado o un tope inválido a la vista.
  bool get _dirty {
    final source = _source;
    if (source == null) return false;
    return !_valid ||
        jsonEncode(_draft.toJson()) != jsonEncode(source.toJson());
  }

  void _cancel() {
    final source = _source;
    if (source != null) setState(() => _adopt(source));
  }

  Future<void> _save() async {
    if (_saving || !_valid) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.updateLeaveLimits(_draft);
      if (!mounted) return;
      setState(() {
        _adopt(saved);
        _saving = false;
      });
      showAppPopup(
        context,
        'Límites de salidas actualizados para todo el personal',
      );
      // Inicio y Motivos muestran estas reglas: se vuelven a leer.
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

  // -------------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------------

  static const _capError = 'Mínimo 1. Déjalo vacío para no poner tope.';

  Widget _numberField(
    Key key,
    TextEditingController controller, {
    required bool valid,
    String? suffix,
    String? hint,
    String error = _capError,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_saving,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (_) => setState(() => _error = null),
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    decoration: adminFieldDecoration(
      hintText: hint ?? 'Sin tope',
      suffixText: suffix,
      errorText: valid ? null : error,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final loading = _source == null && data.isInitialLoad;
    final failed = _source == null && data.hasFailed;

    final List<Widget> children;
    if (loading) {
      children = const [
        SkeletonPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(height: 44, radius: 8),
              SizedBox(height: 18),
              SkeletonBox(height: 48, radius: 8),
              SizedBox(height: 18),
              SkeletonBox(height: 44, radius: 8),
            ],
          ),
        ),
      ];
    } else if (failed) {
      children = [
        LoadErrorNotice(
          message: data.error ?? 'No se pudo cargar el límite de salidas',
          onRetry: () => data.load(force: true),
        ),
      ];
    } else {
      children = [
        SettingsGroup(
          title: 'Por persona',
          description:
              'Cuántas salidas puede hacer cada persona en total, sin '
              'importar el motivo.',
          children: [
            SettingsField(
              label: 'Período',
              hint:
                  'El conteo se reinicia: semana de lunes a domingo; mes '
                  'calendario.',
              child: SegmentedChoice<String>(
                options: _periodOptions,
                selected: _period,
                onChanged: _saving ? null : (v) => setState(() => _period = v),
              ),
            ),
            SettingsField(
              label: 'Máximo de salidas',
              hint: 'Déjalo vacío para no poner tope.',
              child: _numberField(
                const ValueKey('limit-person'),
                _total,
                valid: _totalValid,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Por motivo',
          description:
              'Cuántas veces puede cada persona elegir un mismo motivo. Al '
              'llegar al tope, ese motivo aparece como no permitido.',
          children: [
            SettingsField(
              label: 'Período',
              child: SegmentedChoice<String>(
                options: _periodOptions,
                selected: _reasonPeriod,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _reasonPeriod = v),
              ),
            ),
            SettingsField(
              label: 'Modo',
              hint: _mode == ReasonLimit.general
                  ? 'El mismo tope para todos los motivos.'
                  : 'Un tope distinto por cada motivo.',
              child: SegmentedChoice<String>(
                options: const [
                  (ReasonLimit.general, 'General'),
                  (ReasonLimit.custom, 'Personalizado'),
                ],
                selected: _mode,
                onChanged: _saving ? null : (v) => setState(() => _mode = v),
              ),
            ),
            if (_mode == ReasonLimit.general)
              SettingsField(
                label: 'Tope por período',
                hint:
                    'Ej.: una sola salida por almuerzo al día. Déjalo vacío '
                    'para no poner tope.',
                child: _numberField(
                  const ValueKey('limit-reason-general'),
                  _general,
                  valid: _generalValid,
                  suffix: 'por motivo',
                ),
              )
            else
              ..._customList(),
          ],
        ),
        if (_error != null) SettingsErrorNote(_error!),
      ];
    }

    return SettingsCard(
      icon: Icons.schedule_rounded,
      title: 'Límite de salidas',
      subtitle: 'Cuántas veces puede salir cada persona',
      footer: loading || failed
          ? null
          : SettingsFooter(
              dirty: _dirty,
              valid: _valid,
              saving: _saving,
              onCancel: _cancel,
              onSave: _save,
            ),
      children: children,
    );
  }

  List<Widget> _customList() {
    if (_reasons.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: 18),
          child: Text(
            'Todavía no hay motivos de salida. Sincronízalos desde la '
            'sección Motivos.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      ];
    }
    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Escribe el máximo de veces para cada motivo. Los que dejes vacíos '
          'no tienen tope.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ),
      for (final cap in _reasons)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: Text(
                    cap.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: _numberField(
                  ValueKey('limit-reason-${cap.reasonId}'),
                  _caps[cap.reasonId]!,
                  valid: _capValid(cap),
                  error: 'Mínimo 1',
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
