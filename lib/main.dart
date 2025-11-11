import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:login_app/pages/welcome_page.dart';
import 'package:login_app/pages/notifications_page.dart'; // ✅ Importar tu página real
import 'package:login_app/utils/session_manager.dart';
import 'package:login_app/services/notification_service.dart';

// ✅ Clave global del Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Verificar si el usuario ya está logueado
  final isLoggedIn = await SessionManager.isLoggedIn();
  
  runApp(MyApp(isLoggedIn: isLoggedIn));
  
  // ✅ Inicializar notificaciones DESPUÉS de runApp
  _initializeNotifications();
}

void _initializeNotifications() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // ✅ Pasar la clave global al servicio
    NotificationService.initialize(navigatorKey);
    
    // ✅ CORREGIDO: Usar una verificación diferente para debug
    if (const bool.fromEnvironment('dart.vm.product')) {
      // No hacer nada en producción
    } else {
      print('🔔 Notificaciones inicializadas después del build');
    }
  });
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Club France',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ✅ Misma clave que usa NotificationService
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WelcomePage(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/notifications': (context) => const NotificationsPage(), // ✅ Tu página real
      },
    );
  }
}