import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../data/user_admin_service.dart';
import '../models/device_match.dart';
import '../models/managed_user.dart';

/// Busca a quién está vinculado un teléfono a partir del código que la persona
/// ve en su app y dicta a Recursos Humanos. Devuelve el [DeviceMatch] cuyo
/// dispositivo se quiere desvincular, o `null` si se cerró sin elegir.
class DeviceCodeDialog extends StatefulWidget {
  final UserAdminService? service;

  const DeviceCodeDialog({super.key, this.service});

  @override
  State<DeviceCodeDialog> createState() => _DeviceCodeDialogState();
}

class _DeviceCodeDialogState extends State<DeviceCodeDialog> {
  late final UserAdminService _service = widget.service ?? UserAdminService();
  final _controller = TextEditingController();

  bool _busy = false;
  String? _error;

  /// Null = aún no se buscó; vacía = el código no está vinculado a nadie.
  List<DeviceMatch>? _matches;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _search() async {
    final code = _controller.text.trim();
    if (_busy) return;
    if (code.isEmpty) {
      setState(() => _error = 'Escriba el código que le dictó la persona.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _matches = null;
    });
    try {
      final matches = await _service.findDevicesByCode(code);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return AppModal(
      tone: DialogTone.caution,
      icon: Icons.manage_search_rounded,
      title: 'Buscar por código de dispositivo',
      subtitle: 'El código aparece en la app móvil de la persona',
      maxWidth: 560,
      actions: [
        ModalButton(label: 'Cerrar', onPressed: () => Navigator.pop(context)),
        ModalButton(
          label: 'Buscar',
          primary: true,
          color: AppColors.warning,
          isLoading: _busy,
          onPressed: _search,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pida a la persona el código de su teléfono (por ejemplo '
            'K7M4-Q9XB). Verá a qué cuenta está vinculado y podrá '
            'desvincularlo.',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            onSubmitted: (_) => _search(),
            inputFormatters: [
              // Solo letras, números y guion; se pasa a mayúsculas al escribir.
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
              LengthLimitingTextInputFormatter(10),
              _UpperCaseFormatter(),
            ],
            style: AppText.body.copyWith(letterSpacing: 2),
            decoration: InputDecoration(
              labelText: 'Código del dispositivo',
              prefixIcon: const Icon(
                Icons.smartphone_rounded,
                color: AppColors.darkText,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          if (_error != null) _Note(_error!, danger: true),
          if (matches != null && matches.isEmpty)
            const _Note(
              'Ninguna cuenta tiene vinculado ese dispositivo. Si la persona '
              'no puede ingresar por otro motivo, revise su cuenta en la '
              'lista de usuarios.',
            ),
          if (matches != null)
            for (final match in matches) ...[
              const SizedBox(height: 12),
              _MatchRow(
                match: match,
                formatDate: _formatDate,
                onUnlink: () => Navigator.pop(context, match),
              ),
            ],
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _Note extends StatelessWidget {
  final String message;
  final bool danger;

  const _Note(this.message, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerBg : AppColors.infoBg,
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final DeviceMatch match;
  final String Function(DateTime) formatDate;
  final VoidCallback onUnlink;

  const _MatchRow({
    required this.match,
    required this.formatDate,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (match.item != null) 'Item ${match.item}',
      match.platform.label,
      if (match.boundAt != null) 'vinculado ${formatDate(match.boundAt!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.successBg,
        border: Border(left: BorderSide(color: AppColors.success, width: 6)),
      ),
      child: Row(
        children: [
          Icon(
            match.platform == ClientPlatform.web
                ? Icons.computer_rounded
                : Icons.smartphone_rounded,
            color: AppColors.success,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.name, style: AppText.cardTitle),
                Text(details, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onUnlink,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }
}
