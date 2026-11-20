import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../dashboard/presentation/admin_dashboard_page.dart';
import '../data/auth_service.dart';
import '../models/auth_user.dart';
import '../state/session_controller.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  int _passwordFieldKey = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    //Si el estado del formulario no es valido o ya hay una peticion en curso
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? error;
    AuthUser? user;
    try {
      user = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (user.isPremiseManager) {
        if (user.premise == null || user.premise!.id <= 0) {
          error = 'La cuenta no tiene un predio asignado';
        }
      } else if (!user.isAdmin) {
        try {
          await _authService.logout();
        } catch (_) {
          // Si no se pudo cerrar la sesión igual se rechaza el acceso.
        }
        error = 'No tiene permisos de administrador';
      }
    } on ApiException catch (e) {
      error = e.isUnauthorized ? 'Credenciales incorrectas' : e.message;
    } catch (_) {
      // Cualquier otro fallo (red, respuesta inesperada) también debe
      // devolver el formulario a un estado editable.
      error = 'No se pudo iniciar sesión. Verifique su conexión e intente de nuevo.';
    }

    if (!mounted) return;
    // Siempre se libera el formulario, haya salido bien o mal.
    setState(() => _isLoading = false);

    if (error == null) {
      SessionController.instance.set(user);
      // El responsable de predio no navega: al publicarse su sesión, la raíz de
      // la app (MaterialApp.builder) muestra únicamente su pantalla de QR.
      if (!user!.isPremiseManager) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
        );
      }
    } else {
      // El navegador deja el campo de contraseña "congelado" si se vacía por
      // código tras un error: se reconstruye con una llave nueva (campo
      // limpio y editable) y se cierra el contexto de autocompletado.
      TextInput.finishAutofillContext(shouldSave: false);
      setState(() {
        _passwordFieldKey++;
        _passwordController.text = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocus.requestFocus();
      });
      showAppPopup(context, error, kind: PopupKind.error);
    }
  }

  /// Usuario, contraseña y botón de ingreso.
  Widget _buildForm({required bool wide}) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              style: const TextStyle(color: AppColors.darkText, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Usuario',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: AppColors.darkText,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('password-$_passwordFieldKey'),
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: _isPasswordObscured,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(color: AppColors.darkText, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Contraseña',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 22,
                  color: AppColors.darkText,
                ),
                suffixIcon: IconButton(
                  tooltip: _isPasswordObscured
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _isPasswordObscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 22,
                    color: AppColors.muted,
                  ),
                  onPressed: () => setState(
                    () => _isPasswordObscured = !_isPasswordObscured,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 22),
            AppPrimaryButton(
              label: 'Ingresar',
              loading: _isLoading,
              onPressed: _login,
            ),
            const SizedBox(height: 16),
            const Text(
              'Este equipo queda vinculado a su cuenta. Si cambia de equipo, '
              'pida a TI que lo desvincule.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // En pantallas anchas: a la izquierda la marca y a la derecha el
            // formulario. En pantallas angostas todo va en una sola columna.
            final wide = constraints.maxWidth >= 900;
            if (wide) return _buildWide(constraints);
            return _buildNarrow(constraints);
          },
        ),
      ),
    );
  }

  Widget _buildWide(BoxConstraints constraints) {
    // Con ventanas bajas o letra muy grande la página se desplaza en vez de
    // apretar el contenido.
    return SingleChildScrollView(
      child: SizedBox(
        height: math.max(constraints.maxHeight, 760),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Color(0xFFE6E6E6))),
                ),
                // Con letra muy grande la marca se reduce para caber.
                child: const Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Brand(logoSize: 300, titleSize: 34),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Administradores y responsables de predio.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildForm(wide: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrow(BoxConstraints constraints) {
    final small = constraints.maxHeight < 640;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(
                logoSize: small ? 120 : 170,
                titleSize: 26,
                showSubtitle: false,
              ),
              const SizedBox(height: 22),
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Administradores y responsables de predio.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _buildForm(wide: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo, nombre de la aplicación y para quién es.
class _Brand extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final bool showSubtitle;

  const _Brand({
    required this.logoSize,
    required this.titleSize,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLogo(size: logoSize),
          const SizedBox(height: 18),
          Text(
            'Salidas Temporales',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          if (showSubtitle) ...[
            const SizedBox(height: 6),
            const Text(
              'Panel de administración y pantalla del QR de cada predio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
