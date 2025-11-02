import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = 
      BackgroundLocationService._internal();
  
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  static StreamSubscription<Position>? _positionStream;
  static Timer? _fifteenMinuteTimer;

  // Iniciar el servicio de ubicación automático
  static Future<void> startAutomaticLocationService() async {
    try {
      // Verificar permisos primero
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Servicio de ubicación deshabilitado');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permisos de ubicación denegados permanentemente');
        return;
      }

      // Configurar settings para 20 metros y 15 minutos
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 20, // Actualizar cada 20 metros
      );

      // Escuchar ubicación automáticamente
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        await _handleLocationUpdate(position);
      });

      debugPrint('✅ Servicio automático iniciado: 20m / 15min');
      
      // También iniciar timer de 15 minutos por si no hay movimiento
      _startFifteenMinuteTimer();
      
    } catch (e) {
      debugPrint('❌ Error iniciando servicio automático: $e');
    }
  }

  // Timer de 15 minutos para ubicación por tiempo
  static void _startFifteenMinuteTimer() {
    // Cancelar timer existente si hay uno
    _fifteenMinuteTimer?.cancel();
    
    // Enviar ubicación cada 15 minutos aunque no haya movimiento
    _fifteenMinuteTimer = Timer.periodic(const Duration(minutes: 15), (Timer timer) {
      _getCurrentLocationByTime();
    });
  }

  // Obtener ubicación por tiempo (15 minutos)
  static Future<void> _getCurrentLocationByTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('user_email');
      
      if (userEmail == null) return;

      // Usar LocationSettings en lugar de desiredAccuracy
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      debugPrint('⏰ Ubicación por tiempo (15min): ${position.latitude}, ${position.longitude}');
      await _sendLocationToServer(userEmail, position, true);
      
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación por tiempo: $e');
    }
  }

  // Manejar actualización de ubicación
  static Future<void> _handleLocationUpdate(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('user_email');
      
      if (userEmail == null) {
        debugPrint('❌ No hay usuario logueado');
        return;
      }

      debugPrint('📍 Ubicación por distancia (20m): ${position.latitude}, ${position.longitude}');
      
      // Guardar localmente por si no hay conexión
      await _saveLocationLocally(userEmail, position);
      
      // Intentar enviar al servidor
      await _sendLocationToServer(userEmail, position, false);
      
    } catch (e) {
      debugPrint('❌ Error manejando ubicación: $e');
    }
  }

  // Guardar localmente (cache)
  static Future<void> _saveLocationLocally(String email, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList('pending_locations') ?? [];
      
      final locationData = {
        'email': email,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'fecha': DateTime.now().toIso8601String(),
      };
      
      locations.add(jsonEncode(locationData));
      
      // Mantener máximo 100 ubicaciones pendientes
      if (locations.length > 100) {
        locations.removeAt(0);
      }
      
      await prefs.setStringList('pending_locations', locations);
    } catch (e) {
      debugPrint('❌ Error guardando localmente: $e');
    }
  }

  // Enviar al servidor
  static Future<void> _sendLocationToServer(String email, Position position, bool isTimeBased) async {
    try {
      final url = Uri.parse("https://clubfrance.org.mx/api/guardar_ubicacion.php");
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'latitud': position.latitude,
          'longitud': position.longitude,
          'fecha': DateTime.now().toIso8601String(),
          'tipo': isTimeBased ? 'tiempo' : 'distancia',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint("✅ Ubicación enviada (${isTimeBased ? 'tiempo' : 'distancia'}): ${data['message']}");
        } else {
          debugPrint("❌ Error del servidor: ${data['message']}");
        }
      } else {
        debugPrint("❌ Error HTTP: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('❌ Error enviando ubicación: $e');
    }
  }

  // Detener el servicio
  static Future<void> stopBackgroundLocationService() async {
    try {
      await _positionStream?.cancel();
      _positionStream = null;
      
      _fifteenMinuteTimer?.cancel();
      _fifteenMinuteTimer = null;
      
      debugPrint('🛑 Servicio de ubicación detenido');
    } catch (e) {
      debugPrint('❌ Error deteniendo servicio: $e');
    }
  }

  // Enviar ubicaciones pendientes
  static Future<void> sendAllPendingLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> locations = prefs.getStringList('pending_locations') ?? [];
      
      if (locations.isEmpty) return;

      debugPrint('📤 Enviando ${locations.length} ubicaciones pendientes...');

      List<String> successfulLocations = [];

      for (String locationJson in locations) {
        try {
          final locationData = jsonDecode(locationJson);
          final url = Uri.parse("https://clubfrance.org.mx/api/guardar_ubicacion.php");
          
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(locationData),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              successfulLocations.add(locationJson);
            }
          }
          
          // Pequeña pausa para no saturar el servidor
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('❌ Error enviando ubicación pendiente: $e');
        }
      }

      // Remover solo las exitosas
      locations.removeWhere((location) => successfulLocations.contains(location));
      
      // Actualizar la lista de pendientes
      await prefs.setStringList('pending_locations', locations);
      
      if (successfulLocations.isNotEmpty) {
        debugPrint('✅ ${successfulLocations.length} ubicaciones pendientes enviadas');
      }
      
    } catch (e) {
      debugPrint('❌ Error enviando ubicaciones pendientes: $e');
    }
  }
}