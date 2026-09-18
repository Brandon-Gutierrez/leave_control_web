import 'package:flutter/material.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';

/// Diálogo para crear un predio nuevo y, opcionalmente, asignarle motivos
/// de salida desde el catálogo. Devuelve `true` si se creó correctamente.
class CreatePremiseDialog extends StatefulWidget {
  const CreatePremiseDialog({super.key});

  @override
  State<CreatePremiseDialog> createState() => _CreatePremiseDialogState();
}

class _CreatePremiseDialogState extends State<CreatePremiseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final PremiseService _premiseService = PremiseService();

  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;

  bool _isLoadingReasons = true;
  bool _isSaving = false;
  String? _loadError;
  String? _submitError;
  List<Reason> _availableReasons = [];
  final Set<String> _selectedReasons = {};

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    setState(() {
      _isLoadingReasons = true;
      _loadError = null;
    });
    try {
      final reasons = await _premiseService.getAllReasons();
      if (!mounted) return;
      setState(() {
        _availableReasons = reasons;
        _isLoadingReasons = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoadingReasons = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    try {
      await _premiseService.createPremise(
        _nameController.text.trim(),
        _selectedReasons.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = screenSize.width < 480 ? screenSize.width - 32 : 460.0;
    final dialogMaxHeight = screenSize.height * 0.8;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogMaxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nuevo predio',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: darkText),
                      tooltip: 'Cerrar',
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(color: darkText, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Nombre del predio',
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: primaryRed, width: 1.5),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Motivos de salida permitidos (opcional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Flexible(child: _buildReasonsList()),

                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: const TextStyle(color: primaryRed, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                        : const Text(
                            'Crear predio',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonsList() {
    if (_isLoadingReasons) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: primaryRed)),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              _loadError!,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadReasons, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_availableReasons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No hay motivos en el catálogo todavía.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _availableReasons.length,
      itemBuilder: (context, index) {
        final reason = _availableReasons[index];
        final isSelected = _selectedReasons.contains(reason.name);
        return CheckboxListTile(
          value: isSelected,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: primaryRed,
          title: Text(reason.name, style: const TextStyle(fontSize: 14, color: darkText)),
          onChanged: (checked) {
            setState(() {
              if (checked ?? false) {
                _selectedReasons.add(reason.name);
              } else {
                _selectedReasons.remove(reason.name);
              }
            });
          },
        );
      },
    );
  }
}
