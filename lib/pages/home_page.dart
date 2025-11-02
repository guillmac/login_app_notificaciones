import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_page.dart';
import 'payments_page.dart';
import '../utils/session_manager.dart';
import 'welcome_page.dart';
import 'settings_page.dart';
import 'sports_activities_page.dart';
import 'cultural_activities_page.dart';
import 'events_page.dart';
import 'contact_page.dart';
import '../services/background_location_service.dart';
import 'notifications_page.dart'; // ✅ AGREGA ESTA LÍNEA

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _locationServicesInitialized = false;
  StreamSubscription<Position>? _locationSubscription;
  DateTime? _lastLocationTime;
  Position? _lastLocation;
  bool _serverErrorDetected = false;
  
  // Animación
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeLocationServices();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutBack,
    ));
  }

  Future<void> _initializeLocationServices() async {
    if (_locationServicesInitialized) return;
    
    // Guardar email para uso en background
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', widget.user['email'] ?? '');
    
    // Enviar ubicaciones pendientes al iniciar
    await BackgroundLocationService.sendAllPendingLocations();
    
    // ✅ SOLO UNA VEZ: Obtener ubicación actual al entrar al Home
    await _obtenerUbicacionUnaVez();
    
    // ✅ Iniciar MONITOREO CONTINUO con filtros
    await _startLocationMonitoring();
    
    setState(() {
      _locationServicesInitialized = true;
    });
  }

  Future<void> _obtenerUbicacionUnaVez() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        debugPrint('📍 Servicio de ubicación no disponible');
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          debugPrint('📍 Permisos de ubicación denegados');
          return;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        debugPrint('📍 Permisos de ubicación denegados permanentemente');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📍 Ubicación INICIAL obtenida UNA VEZ: Lat: ${position.latitude}, Lon: ${position.longitude}');
      
      // ✅ Guardar como última ubicación para control de distancia
      _lastLocation = position;
      _lastLocationTime = DateTime.now();
      
      await _enviarUbicacionConReintentos(
        widget.user['email'] ?? '',
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación inicial: $e');
    }
  }

  Future<void> _startLocationMonitoring() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        return;
      }

      // ✅ Configurar stream con filtros
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10, // ✅ Solo actualiza cada 10 metros
        ),
      ).listen(
        (Position position) {
          _procesarNuevaUbicacion(position);
        },
        onError: (error) {
          debugPrint('❌ Error en monitoreo de ubicación: $error');
        },
      );

      debugPrint('📍 Monitoreo de ubicación iniciado (10m / 15min)');
    } catch (e) {
      debugPrint('❌ Error iniciando monitoreo: $e');
    }
  }

  void _procesarNuevaUbicacion(Position newPosition) {
    final now = DateTime.now();
    
    // ✅ Verificar filtro de tiempo (15 minutos)
    if (_lastLocationTime != null) {
      final timeDifference = now.difference(_lastLocationTime!);
      if (timeDifference.inMinutes < 15) {
        debugPrint('📍 Ubicación ignorada - Filtro tiempo: ${timeDifference.inMinutes}min');
        return;
      }
    }

    // ✅ Verificar filtro de distancia (10 metros)
    if (_lastLocation != null) {
      final distance = Geolocator.distanceBetween(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      
      if (distance < 10) {
        debugPrint('📍 Ubicación ignorada - Filtro distancia: ${distance.toStringAsFixed(1)}m');
        return;
      }
    }

    // ✅ PASÓ LOS FILTROS - Procesar ubicación
    debugPrint('📍 Nueva ubicación PROCESADA: Lat: ${newPosition.latitude}, Lon: ${newPosition.longitude}');
    
    // Actualizar controles
    _lastLocation = newPosition;
    _lastLocationTime = now;
    
    // Enviar al servidor
    _enviarUbicacionConReintentos(
      widget.user['email'] ?? '',
      newPosition.latitude,
      newPosition.longitude,
    );
  }

  Future<void> _enviarUbicacionConReintentos(String email, double lat, double lng, {int maxIntentos = 1}) async {
    // ✅ VERIFICAR CONEXIÓN A INTERNET PRIMERO
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty) {
        debugPrint('🌐 Sin conexión a internet, guardando localmente');
        await _guardarUbicacionPendiente(email, lat, lng);
        return;
      }
    } catch (e) {
      debugPrint('🌐 Error de conexión: $e, guardando localmente');
      await _guardarUbicacionPendiente(email, lat, lng);
      return;
    }

    // ✅ EVITAR SPAM SI EL SERVIDOR ESTÁ CAÍDO
    if (_serverErrorDetected) {
      debugPrint('🔄 Servidor con problemas conocidos, guardando localmente');
      await _guardarUbicacionPendiente(email, lat, lng);
      return;
    }

    for (int intento = 1; intento <= maxIntentos; intento++) {
      try {
        bool exito = await _enviarUbicacionAlServidor(email, lat, lng);
        if (exito) {
          debugPrint('✅ Ubicación enviada exitosamente');
          return;
        } else {
          debugPrint('🔄 Reintentando ubicación (intento $intento/$maxIntentos)');
          if (intento < maxIntentos) {
            await Future.delayed(const Duration(seconds: 3));
          }
        }
      } catch (e) {
        debugPrint('❌ Error en intento $intento: $e');
        if (intento < maxIntentos) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }
    
    // Si todos los intentos fallan, guardar localmente
    await _guardarUbicacionPendiente(email, lat, lng);
  }

  Future<bool> _enviarUbicacionAlServidor(String email, double lat, double lng) async {
    try {
      final url = Uri.parse("https://clubfrance.org.mx/api/guardar_ubicacion.php");

      // ✅ ENVIAR DATOS COMO NÚMEROS (NO STRINGS)
      final Map<String, dynamic> requestBody = {
        'email': email,
        'latitud': lat, // ✅ Enviar como número, no como string
        'longitud': lng, // ✅ Enviar como número, no como string
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'monitoreo',
      };

      debugPrint('📤 Enviando datos: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      // ✅ MEJOR MANEJO DE RESPUESTAS
      if (response.body.isEmpty || response.body.trim().isEmpty) {
        debugPrint('❌ Servidor respondió vacío');
        
        // Si es error del servidor, marcar como problemático
        if (response.statusCode >= 500) {
          _serverErrorDetected = true;
          // Reactivar después de 5 minutos
          Future.delayed(const Duration(minutes: 5), () {
            _serverErrorDetected = false;
            debugPrint('🔄 Reactivando envíos al servidor');
          });
        }
        return false;
      }

      // ✅ VERIFICAR STATUS CODE
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            debugPrint("✅ Ubicación guardada: ${data['message']}");
            return true;
          } else {
            debugPrint("❌ Error del servidor: ${data['message']}");
            return false;
          }
        } catch (e) {
          debugPrint('❌ Error parseando JSON: $e');
          // Si el status es 200 pero no puede parsear, podría ser éxito
          return true;
        }
      } else if (response.statusCode == 400) {
        debugPrint('❌ Error 400 - Datos inválidos');
        try {
          final data = jsonDecode(response.body);
          debugPrint('❌ Detalles: ${data['message']}');
        } catch (_) {}
        return false;
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}');
        
        // Marcar error del servidor para evitar spam
        if (response.statusCode >= 500) {
          _serverErrorDetected = true;
          Future.delayed(const Duration(minutes: 5), () {
            _serverErrorDetected = false;
          });
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error enviando ubicación: $e');
      return false;
    }
  }

  Future<void> _guardarUbicacionPendiente(String email, double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList('pending_locations') ?? [];
      
      final locationData = {
        'email': email,
        'latitud': lat,
        'longitud': lng,
        'fecha': DateTime.now().toIso8601String(),
        'intentos': 0,
        'tipo': 'monitoreo',
      };
      
      locations.add(jsonEncode(locationData));
      await prefs.setStringList('pending_locations', locations);
      debugPrint('📍 Ubicación guardada localmente para reintento posterior');
    } catch (e) {
      debugPrint('❌ Error guardando ubicación local: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _locationSubscription?.cancel();
    debugPrint('📍 Monitoreo de ubicación detenido');
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          );
        },
      );

      await BackgroundLocationService.stopBackgroundLocationService();
      await SessionManager.logout();

      if (!context.mounted) return;
      
      // Cerrar el diálogo de carga
      Navigator.of(context).pop();
      
      // Navegar a la página de bienvenida con animación
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      
      // Cerrar el diálogo de carga en caso de error
      Navigator.of(context).pop();
      
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Error al cerrar sesión",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    _animationController.forward();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.logout,
                  size: 48,
                  color: Colors.red,
                ),
                SizedBox(height: 8),
                Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Text(
              "¿Estás seguro de que quieres cerrar sesión?",
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _animationController.reverse();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _logout(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Cerrar Sesión",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _animationController.reverse();
    });
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hola, ${widget.user['primer_nombre'] ?? ''}",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Usuario: ${widget.user['numero_usuario'] ?? ''}",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout, 
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () => _showLogoutConfirmation(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             _buildSectionButton(
              context,
              "Mi membresía",
              Icons.verified_user,
              () => _navigateToPage(context, const PaymentsPage()),
            ),
            _buildSectionButton(
              context,
              "Actividades Deportivas",
              Icons.sports_soccer,
              () => _navigateToPage(
                context,
                const SportsActivitiesPage(),
              ),
            ),
            _buildSectionButton(
              context,
              "Actividades Culturales",
              Icons.music_note,
              () => _navigateToPage(
                context,
                const CulturalActivitiesPage(),
              ),
            ),
            _buildSectionButton(
              context,
              "L' Espace",
              Icons.card_giftcard,
              () => _navigateToPage(
                context,
                _PlaceholderPage(title: "L'Espace"),
              ),
            ),
            _buildSectionButton(
              context,
              "Eventos",
              Icons.event,
              () => _navigateToPage(context, const EventsPage()),
            ),
            _buildSectionButton(
            context,
            "Notificaciones",
            Icons.notifications,
            () => _navigateToPage(context, const NotificationsPage()), // Actualizado
            ),
            _buildSectionButton(
              context,
              "Torneos",
              Icons.emoji_events,
              () => _navigateToPage(context, _PlaceholderPage(title: "Torneos")),
            ),
            _buildSectionButton(
              context,
              "Entrenadores",
              Icons.fitness_center,
              () => _navigateToPage(
                context,
                _PlaceholderPage(title: "Entrenadores"),
              ),
            ),

            _buildSectionButton(
              context,
              "Beneficios",
              Icons.card_giftcard,
              () => _navigateToPage(
                context,
                _PlaceholderPage(title: "Beneficios"),
              ),
            ),
            _buildSectionButton(
              context,
              "Contacto",
              Icons.contact_mail,
              () => _navigateToPage(context, const ContactPage()),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: 0,
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontFamily: 'Montserrat'),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Montserrat'),
        onTap: (index) => _onBottomNavTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Perfil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Config.",
          ),
        ],
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(email: widget.user['email'] ?? ''),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsPage(user: widget.user)),
        );
        break;
    }
  }

  Widget _buildSectionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE3F2FD),
          foregroundColor: const Color(0xFF0D47A1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          elevation: 1,
          shadowColor: const Color(0xFF000000).withValues(alpha: 0.1),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              icon, 
              size: 28, 
              color: const Color(0xFF0D47A1),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF0D47A1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title, 
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a1a),
              Color(0xFF2d2d2d),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: const Color(0xFFFFFF00).withValues(alpha: 0.7),
              ),
              const SizedBox(height: 20),
              Text(
                "Próximamente: $title",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Estamos trabajando en esta funcionalidad\npara ofrecerte la mejor experiencia",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontFamily: 'Montserrat',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text(
                  "Volver al Inicio",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
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