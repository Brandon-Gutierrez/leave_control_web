import 'package:flutter/material.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'create_premise_dialog.dart';
import 'generator_qr_page.dart';

/// Sección "Predios" del panel de administración: búsqueda, listado con sus
/// motivos permitidos y creación de predios nuevos.
class PremisesView extends StatefulWidget {
  /// Se llama cuando el token de sesión ya no es válido (401).
  final VoidCallback onUnauthorized;

  const PremisesView({super.key, required this.onUnauthorized});

  @override
  State<PremisesView> createState() => PremisesViewState();
}

class PremisesViewState extends State<PremisesView> {
  // Paleta de colores unificada
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;

  // Separación entre tarjetas
  static const double _gap = 12;

  final _searchController = TextEditingController();
  final PremiseService _premiseService = PremiseService();

  List<Reason> _allReasons = [];
  List<Premise> _prediosList = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Recarga la lista de predios y el catálogo de motivos. Público para que
  /// otras secciones (p. ej. "Inicio") puedan refrescar estos datos.
  Future<void> refresh() => _fetchData();

  /// Abre el formulario de creación de predios. Público para que la sección
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateDialog() => _openCreatePremiseDialog();

  /// Sincroniza el catálogo de motivos con el sistema externo, muestra el
  /// resultado y refresca los datos. Público para que "Inicio" lo use.
  Future<void> syncReasons() => _syncReasons();

  int get premiseCount => _prediosList.length;

  List<Premise> get _filteredPredios {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return _prediosList;
    return _prediosList
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _premiseService.getPremisesWithReasons(),
        _premiseService.getAllReasons(),
      ]);
      if (!mounted) return;
      setState(() {
        _prediosList = results[0] as List<Premise>;
        _allReasons = results[1] as List<Reason>;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } catch (_) {
      _showSnackBar('No se pudieron cargar los predios', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openCreatePremiseDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const CreatePremiseDialog(),
    );
    if (created == true) {
      _showSnackBar('Predio creado correctamente', Colors.green);
      _fetchData();
    }
  }

  Future<void> _syncReasons() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final message = await _premiseService.syncReasons();
      _showSnackBar(message, Colors.green);
      await _fetchData();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _navigateToQrPage(Premise premise) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrPage(premise: premise)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryRed))
        : LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= Breakpoints.desktop
                  ? 3
                  : width >= Breakpoints.tablet
                      ? 2
                      : 1;
              final horizontalPadding = width >= Breakpoints.tablet ? 32.0 : 16.0;
              final isNarrow = width < 560;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // BARRA DE BÚSQUEDA Y ACCIONES
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: isNarrow
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSearchField(),
                                      const SizedBox(height: 12),
                                      _buildAddButton(),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(child: _buildSearchField()),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.refresh_rounded, color: darkText, size: AppDimens.iconSize),
                                        tooltip: 'Actualizar',
                                        onPressed: _isLoading ? null : _fetchData,
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(width: 220, child: _buildAddButton()),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // LISTA / GRILLA DE PREDIOS
                        Expanded(
                          child: _filteredPredios.isEmpty
                              ? Center(
                                  child: Text(
                                    'No se encontraron predios.',
                                    style: AppText.body.copyWith(color: Colors.grey.shade600),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _fetchData,
                                  color: Colors.white,
                                  backgroundColor: primaryRed,
                                  child: columns == 1
                                      ? _buildList()
                                      : _buildGrid(columns),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: AppDimens.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: _openCreatePremiseDialog,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Agregar predio'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar predio por nombre...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        prefixIcon:
            const Icon(Icons.search_rounded, color: darkText, size: AppDimens.iconSize),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: const BorderSide(color: primaryRed, width: 1.5),
        ),
      ),
    );
  }

  // Una columna (pantallas angostas)
  Widget _buildList() {
    final predios = _filteredPredios;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: predios.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: _gap),
        child: _buildPremiseCard(predios[index]),
      ),
    );
  }

  // Varias columnas (tablet / escritorio). Wrap permite que cada tarjeta
  // se expanda sin alterar el alto de las demás columnas.
  Widget _buildGrid(int columns) {
    final predios = _filteredPredios;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _gap),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final predio in predios)
                SizedBox(
                  width: cardWidth,
                  child: _buildPremiseCard(predio),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiseCard(Premise predio) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        // Elimina las líneas divisorias por defecto del ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<int>(predio.id),
          iconColor: primaryRed,
          collapsedIconColor: darkText,
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            predio.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${predio.reasonNames.length} de ${_allReasons.length} motivos permitidos',
              style: AppText.caption,
            ),
          ),
          trailing: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: const Text(
              'QR',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _navigateToQrPage(predio),
          ),
          children: [
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivos de salida permitidos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Lista minimalista de motivos
                  ..._allReasons.map((reason) {
                    final isAssigned = predio.reasonNames.any(
                      (r) => r.name.toLowerCase() == reason.name.toLowerCase(),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Icon(
                            isAssigned
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: isAssigned
                                ? primaryRed
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason.name,
                              style: TextStyle(
                                fontSize: 15,
                                color: isAssigned
                                    ? darkText
                                    : Colors.grey.shade500,
                                fontWeight: isAssigned
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
