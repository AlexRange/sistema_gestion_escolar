import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isRegister = false;
  final _nameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  // 🔥 MÉTODO CORREGIDO
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      if (_isRegister) {
        // REGISTRO
        await notifier.register(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
          _nameCtrl.text.trim(),
          _schoolCtrl.text.isEmpty ? null : _schoolCtrl.text.trim(),
        );

        if (!mounted) return;

        // Cerrar sesión para obligar verificación
        await notifier.signOut();

        _showVerificationDialog();
        return;
      }

      // LOGIN
      await notifier.signIn(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      if (!mounted) return;

      // Verificar email
      await ref.read(authRepositoryProvider).reloadUser();
      final verified = ref.read(authRepositoryProvider).isEmailVerified;

      if (!verified) {
        await notifier.signOut();
        _showVerificationDialog();
        return;
      }

      // Acceso permitido
      context.go('/dashboard');

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // 🔥 DIÁLOGO CORREGIDO (sin catchError)
  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Verifica tu correo',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                size: 60, color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              'Revisa tu correo:\n${_emailCtrl.text}\n\nTambién revisa SPAM.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final cred = await FirebaseAuth.instance
                    .signInWithEmailAndPassword(
                  email: _emailCtrl.text.trim(),
                  password: _passCtrl.text.trim(),
                );

                await cred.user?.sendEmailVerification();
                await FirebaseAuth.instance.signOut();

                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Correo reenviado'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (_) {}
            },
            child: const Text('Reenviar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Correo o contraseña incorrectos';
    }
    if (raw.contains('email-already-in-use')) return 'Ese correo ya está registrado';
    if (raw.contains('weak-password')) return 'La contraseña es muy débil (mín. 6 caracteres)';
    if (raw.contains('network-request-failed')) return 'Sin conexión a internet';
    return 'Error al iniciar sesión. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/LogoMentorApp.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegister ? 'Crea tu cuenta' : 'Inicia sesión',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 20),
                      /*Text(
                        'Mentor',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                      ),*/ // El título se eliminó para dar más protagonismo al logo y evitar redundancia
                      if (_isRegister) ...[
                        _buildField(
                          controller: _nameCtrl,
                          label: 'Nombre completo',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _schoolCtrl,
                          label: 'Escuela (opcional)',
                          icon: Icons.account_balance_outlined,
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildField(
                        controller: _emailCtrl,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _passCtrl,
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      if (!_isRegister)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showResetDialog,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _isRegister ? 'Crear cuenta' : 'Iniciar sesión',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister
                              ? '¿Ya tienes cuenta? Inicia sesión'
                              : '¿No tienes cuenta? Regístrate',
                          style:
                              const TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  void _showResetDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(authNotifierProvider.notifier)
                  .resetPassword(ctrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Revisa tu correo para restablecer tu contraseña')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
