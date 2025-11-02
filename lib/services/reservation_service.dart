import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ReservationService {
  static const String baseUrl = 'https://tu-dominio.com/api/';
  
  // Logger simplificado
  static final Logger _logger = Logger();

  // Obtener lugares ocupados desde el backend
  static Future<List<int>> getLugaresOcupados(String actividadId) async {
    try {
      _logger.i('Obteniendo lugares ocupados para actividad: $actividadId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/obtener_lugares_ocupados.php?actividad_id=$actividadId')
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> lugares = data['lugares_ocupados'] ?? [];
        final List<int> resultado = lugares.map<int>((lugar) => int.tryParse(lugar.toString()) ?? 0)
            .where((lugar) => lugar > 0)
            .toList();
        
        _logger.i('Lugares ocupados obtenidos: $resultado para actividad: $actividadId');
        return resultado;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al obtener lugares ocupados');
        return <int>[];
      }
    } catch (e) {
      _logger.e('Error obteniendo lugares ocupados para actividad: $actividadId - Error: $e');
      return <int>[];
    }
  }
  
  // Reservar un lugar
  static Future<Map<String, dynamic>> reservarLugar({
    required String actividadId,
    required int numeroLugar,
    required String usuarioId,
  }) async {
    try {
      _logger.i('Reservando lugar $numeroLugar para actividad: $actividadId, usuario: $usuarioId');
      
      final Map<String, dynamic> requestBody = {
        'actividad_id': actividadId,
        'numero_lugar': numeroLugar,
        'usuario_id': usuarioId,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/reservar_lugar.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> resultado = json.decode(response.body);
        _logger.i('Respuesta de reserva: $resultado');
        return resultado;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al reservar lugar');
        return <String, dynamic>{
          'success': false, 
          'message': 'Error de conexión: ${response.statusCode}'
        };
      }
    } catch (e) {
      _logger.e('Error reservando lugar $numeroLugar para actividad: $actividadId - Error: $e');
      return <String, dynamic>{
        'success': false, 
        'message': 'Error: $e'
      };
    }
  }
  
  // Cancelar reserva
  static Future<Map<String, dynamic>> cancelarReserva({
    required String actividadId,
    required String usuarioId,
  }) async {
    try {
      _logger.i('Cancelando reserva para actividad: $actividadId, usuario: $usuarioId');
      
      final Map<String, dynamic> requestBody = {
        'actividad_id': actividadId,
        'usuario_id': usuarioId,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/cancelar_reserva.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> resultado = json.decode(response.body);
        _logger.i('Respuesta de cancelación: $resultado');
        return resultado;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al cancelar reserva');
        return <String, dynamic>{
          'success': false, 
          'message': 'Error de conexión: ${response.statusCode}'
        };
      }
    } catch (e) {
      _logger.e('Error cancelando reserva para actividad: $actividadId - Error: $e');
      return <String, dynamic>{
        'success': false, 
        'message': 'Error: $e'
      };
    }
  }

  // Verificar estado de reserva
  static Future<Map<String, dynamic>> verificarEstadoReserva({
    required String actividadId,
    required String usuarioId,
  }) async {
    try {
      _logger.i('Verificando estado de reserva para actividad: $actividadId, usuario: $usuarioId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/verificar_reserva.php?actividad_id=$actividadId&usuario_id=$usuarioId')
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> resultado = json.decode(response.body);
        _logger.i('Estado de reserva: $resultado');
        return resultado;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al verificar reserva');
        return <String, dynamic>{
          'success': false, 
          'message': 'Error de conexión: ${response.statusCode}'
        };
      }
    } catch (e) {
      _logger.e('Error verificando reserva para actividad: $actividadId - Error: $e');
      return <String, dynamic>{
        'success': false, 
        'message': 'Error: $e'
      };
    }
  }

  // Obtener todas las reservas de un usuario
  static Future<List<Map<String, dynamic>>> getReservasUsuario(String usuarioId) async {
    try {
      _logger.i('Obteniendo reservas para usuario: $usuarioId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/reservas_usuario.php?usuario_id=$usuarioId')
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> reservas = data['reservas'] ?? [];
        final List<Map<String, dynamic>> reservasList = reservas
            .whereType<Map<String, dynamic>>()
            .toList();
        
        _logger.i('Reservas obtenidas: ${reservasList.length} para usuario: $usuarioId');
        return reservasList;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al obtener reservas del usuario');
        return <Map<String, dynamic>>[];
      }
    } catch (e) {
      _logger.e('Error obteniendo reservas para usuario: $usuarioId - Error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  // Liberar lugar temporalmente reservado
  static Future<Map<String, dynamic>> liberarLugar({
    required String actividadId,
    required int numeroLugar,
    required String usuarioId,
  }) async {
    try {
      _logger.i('Liberando lugar $numeroLugar para actividad: $actividadId, usuario: $usuarioId');
      
      final Map<String, dynamic> requestBody = {
        'actividad_id': actividadId,
        'numero_lugar': numeroLugar,
        'usuario_id': usuarioId,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/liberar_lugar.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> resultado = json.decode(response.body);
        _logger.i('Respuesta de liberación: $resultado');
        return resultado;
      } else {
        _logger.e('Error HTTP ${response.statusCode} al liberar lugar');
        return <String, dynamic>{
          'success': false, 
          'message': 'Error de conexión: ${response.statusCode}'
        };
      }
    } catch (e) {
      _logger.e('Error liberando lugar $numeroLugar para actividad: $actividadId - Error: $e');
      return <String, dynamic>{
        'success': false, 
        'message': 'Error: $e'
      };
    }
  }

  // Método para limpiar el logger cuando sea necesario
  static void dispose() {
    _logger.close();
  }
}