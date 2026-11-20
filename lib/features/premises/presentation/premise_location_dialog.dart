import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../../map/models/lat_lng.dart';
import '../../map/presentation/map_library.dart';

/// Cuadro para elegir (o cambiar) el punto del predio en el mapa. Devuelve el
/// punto elegido, o null si se cancela. El mapa se descarga la primera vez que
/// se abre.
class PremiseLocationDialog extends StatefulWidget {
  final String premiseName;

  /// Punto actual; null si el predio todavía no tiene ubicación.
  final LatLng? initial;

  const PremiseLocationDialog({
    super.key,
    required this.premiseName,
    required this.initial,
  });

  @override
  State<PremiseLocationDialog> createState() => _PremiseLocationDialogState();
}

class _PremiseLocationDialogState extends State<PremiseLocationDialog> {
  late LatLng? _picked = widget.initial;

  bool get _changed => _picked != null && _picked != widget.initial;

  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: DialogTone.configure,
      icon: Icons.edit_location_alt_rounded,
      title: widget.initial == null ? 'Fijar ubicación' : 'Cambiar ubicación',
      subtitle: widget.premiseName.isEmpty ? null : widget.premiseName,
      maxWidth: 760,
      actions: [
        ModalButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
        ModalButton(
          label: 'Usar esta ubicación',
          primary: true,
          color: AppColors.info,
          onPressed: _changed ? () => Navigator.pop(context, _picked) : null,
        ),
      ],
      child: deferredLocationPicker(
        radiusMeters: AdminDataStore.instance.geofenceRadiusMeters,
        initial: _picked,
        onChanged: (p) => setState(() => _picked = p),
      ),
    );
  }
}
