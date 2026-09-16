import 'package:flutter/material.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';
import 'generator_qr_page.dart';
import 'login_admin_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // Paleta de colores unificada
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;
  static const lightBg = AppColors.lightBg;

  // Separación entre tarjetas
  static const double _gap = 12;

  final _searchController = TextEditingController();
  final PremiseService _premiseService = PremiseService();
  final AuthService _authService = AuthService();

  List<Reason> _allReasons = [];
  List<Premise> _prediosList = [];
  String _searchQuery = '';
  bool _isLoading = true;

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
        _goToLogin();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } catch (_) {
      _showSnackBar('Error al cargar datos', Colors.red);
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

  Future<void> _logout() async {
    await _authService.logout();
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginAdminPage()),
      (route) => false,
    );
  }

  void _navigateToQrPage(Premise premise) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrPage(premise: premise)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'ADMINISTRACIÓN DE PREDIOS',
            style: TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: darkText, size: 22),
            tooltip: 'Actualizar',
            onPressed: _isLoading ? null : _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: darkText, size: 22),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryRed))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= Breakpoints.desktop
                      ? 3
                      : width >= Breakpoints.tablet
                          ? 2
                          : 1;
                  final horizontalPadding =
                      width >= Breakpoints.tablet ? 32.0 : 16.0;

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
                            // LOGO COMTECO
                            Center(
                              child: Image.asset(
                                'rsc/comteco.png',
                                height: 45,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.business_rounded,
                                  size: 40,
                                  color: darkText,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // CAMPO DE BÚSQUEDA MINIMALISTA
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 640),
                                child: _buildSearchField(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // LISTA / GRILLA DE PREDIOS
                            Expanded(
                              child: _filteredPredios.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No se encontraron predios.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 15,
                                        ),
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
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: const TextStyle(fontSize: 15, color: darkText),
      decoration: InputDecoration(
        hintText: 'Buscar predio por nombre...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon:
            const Icon(Icons.search_rounded, color: darkText, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(12),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: darkText,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${predio.reasonNames.length} de ${_allReasons.length} motivos permitidos',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: const Text(
              'QR',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                      fontSize: 13,
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
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(
                            isAssigned
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isAssigned
                                ? primaryRed
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason.name,
                              style: TextStyle(
                                fontSize: 14,
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
