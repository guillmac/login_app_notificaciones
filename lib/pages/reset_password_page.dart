import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String resetToken;
  
  const ResetPasswordPage({
    super.key, 
    required this.email,
    required this.resetToken
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  void _logInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ RESET PASSWORD: $message');
    }
  }

  void _logError(String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ RESET PASSWORD ERROR: $message - $error');
      } else {
        debugPrint('❌ RESET PASSWORD ERROR: $message');
      }
    }
  }

  Future<void> _resetPassword() async {
    // Verificaciones síncronas - no necesitan mounted
    if (_newPasswordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa y confirma tu nueva contraseña")),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Las contraseñas no coinciden")),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La contraseña debe tener al menos 6 caracteres")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/reset_password.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email, // ← Ahora usamos el email
          "token": widget.resetToken,
          "new_password": _newPasswordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _logInfo('Contraseña restablecida exitosamente');
        
        if (!mounted) return;
        
        // Mostrar diálogo de éxito
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a1a),
            title: const Text(
              "Contraseña Actualizada",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "Tu contraseña ha sido restablecida exitosamente. Ahora puedes iniciar sesión con tu nueva contraseña.",
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  if (mounted) {
                    Navigator.pop(context); // Volver al login
                  }
                },
                child: const Text(
                  "Ir al Login",
                  style: TextStyle(
                    color: Colors.amber,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final message = data['message'] ?? "Error al restablecer contraseña";
        _logError('Error en reset password: $message');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _logError('Error de conexión en reset password', e);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: onToggleVisibility,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nueva Contraseña',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Crea una nueva contraseña para: ${widget.email}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 30),
              _buildPasswordField(
                label: "Nueva contraseña",
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  if (!mounted) return;
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                label: "Confirmar contraseña",
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  if (!mounted) return;
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Restablecer Contraseña',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}