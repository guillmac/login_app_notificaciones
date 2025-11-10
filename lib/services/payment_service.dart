// lib/services/payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class PaymentService {
  static const String _baseUrl = 'https://clubfrance.org.mx/api';
  static const String _paymentUrl = 'https://www.adquiramexico.com.mx:443/mExpress/pago/avanzado';
  static const String _idexpress = '3103';
  static const String _secretKey = 'WCCBa2c8HdanSiRP=2mV';

  // Generar signature usando HMAC-SHA256
  static String _generateSignature(String message) {
    var key = utf8.encode(_secretKey);
    var bytes = utf8.encode(message);
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  // Generar datos de pago
  static Future<Map<String, dynamic>> generatePaymentData({
    required String actividadNombre,
    required String actividadId,
    required String numeroUsuario,
    required String nombreUsuario,
    required String apellidoUsuario,
    required double precio,
    required String concepto,
  }) async {
    try {
      // Formato: CONCEPTO-NUMERO_USUARIO-NOMBRE APELLIDO-FECHA
      final referencia = '$concepto-$numeroUsuario-$nombreUsuario $apellidoUsuario-${DateTime.now().toString().substring(0, 10)}';
      final importe = precio.toStringAsFixed(2);
      
      // Generar signature
      final message = referencia + importe + _idexpress;
      final signature = _generateSignature(message);

      return {
        'success': true,
        'referencia': referencia,
        'importe': importe,
        'signature': signature,
        'idexpress': _idexpress,
        'payment_url': _paymentUrl,
        'urlretorno': 'https://clubfrance.org.mx/api/payment_callback.php',
        'actividad_id': actividadId,
        'actividad_nombre': actividadNombre,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al generar datos de pago: $e'
      };
    }
  }

  // Verificar estado de pago
  static Future<Map<String, dynamic>> verifyPayment(String referencia) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify_payment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'referencia': referencia}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Error de conexión'};
    } catch (e) {
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // Guardar información del pago en la base de datos
  static Future<Map<String, dynamic>> savePaymentRecord({
    required String referencia,
    required String actividadId,
    required String actividadNombre,
    required String numeroUsuario,
    required String nombreUsuario,
    required double importe,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/save_payment_record.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'referencia': referencia,
          'actividad_id': actividadId,
          'actividad_nombre': actividadNombre,
          'numero_usuario': numeroUsuario,
          'nombre_usuario': nombreUsuario,
          'importe': importe,
          'fecha_solicitud': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Error de conexión'};
    } catch (e) {
      return {'success': false, 'error': 'Error: $e'};
    }
  }
}