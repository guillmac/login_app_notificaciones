// services/clase_muestra_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ClaseMuestraService {
  static const String _baseUrl = 'https://clubfrance.org.mx/api';

  // Marcar clase muestra como tomada
  static Future<Map<String, dynamic>> marcarClaseTomada({
    required String numeroUsuario,
    required String actividadId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/marcar_clase_tomada.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'numero_usuario': numeroUsuario,
          'actividad_id': actividadId,
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

  // Verificar clases muestra tomadas
  static Future<Map<String, dynamic>> getClasesTomadas(String numeroUsuario) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_clases_tomadas.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'numero_usuario': numeroUsuario}),
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