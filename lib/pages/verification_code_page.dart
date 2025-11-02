import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'reset_password_page.dart';

class VerificationCodePage extends StatefulWidget {
  final String email;
  
  const VerificationCodePage({super.key, required this.email});

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends State<VerificationCodePage> {
  final List<TextEditingController> _codeControllers = 
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && _codeControllers[i].text.isEmpty) {
          if (i > 0 && mounted) {
            _focusNodes[i - 1].requestFocus();
          }
        }
      });
    }
  }

  void _startCountdown() {
    _canResend = false;
    _countdown = 60;
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        if (_countdown > 0) {
          _startCountdown();
        } else {
          if (mounted) {
            setState(() {
              _canResend = true;
            });
          }
        }
      }
    });
  }

  void _logInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ VERIFICATION: $message');
    }
  }

  void _logError(String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ VERIFICATION ERROR: $message - $error');
      } else {
        debugPrint('❌ VERIFICATION ERROR: $message');
      }
    }
  }

  Future<void> _verifyCode() async {
    String code = _codeControllers.map((controller) => controller.text).join();
    
    if (code.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa el código completo de 6 dígitos")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/verify_reset_code.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "code": code,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _logInfo('Código verificado exitosamente');
        
        if (!mounted) return;
        
        // Navegar a la página de reset de contraseña
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              email: widget.email,
              resetToken: data['reset_token'] ?? code,
            ),
          ),
        );
      } else {
        final message = data['message'] ?? "Código inválido";
        _logError('Error en verificación: $message');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        
        // Limpiar los campos en caso de error
        _clearCodeFields();
      }
    } catch (e) {
      _logError('Error de conexión en verificación', e);
      
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

  Future<void> _resendCode() async {
    if (!mounted) return;
    setState(() => _resending = true);

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/recover_password.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
        
        _startCountdown();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Error al reenviar código"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _resending = false);
  }

  void _clearCodeFields() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
    if (mounted) {
      _focusNodes[0].requestFocus();
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Verificar si todos los campos están llenos
    String fullCode = _codeControllers.map((c) => c.text).join();
    if (fullCode.length == 6) {
      _verifyCode();
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildCodeField(int index) {
    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white54),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber),
          ),
          filled: true,
          fillColor: const Color(0xFF2d2d2d),
        ),
        onChanged: (value) => _onCodeChanged(index, value),
      ),
    );
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
                'Código de Verificación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingresa el código de 6 dígitos que enviamos a:\n${widget.email}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 40),
              
              // Campos de código
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) => _buildCodeField(index)),
              ),
              
              const SizedBox(height: 30),
              
              // Botón de verificación
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
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
                          'Verificar Código',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Reenviar código
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resending ? null : _resendCode,
                        child: _resending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.amber,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Reenviar código',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      )
                    : Text(
                        'Podrás reenviar el código en $_countdown segundos',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Montserrat',
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