import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:login_app/pages/welcome_page.dart'; // ✅ CAMBIAR de login_page a welcome_page
import 'package:login_app/utils/session_manager.dart';
import 'package:login_app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Inicializar servicio de notificaciones
  await NotificationService.initialize();
  
  // Verificar si el usuario ya está logueado
  final isLoggedIn = await SessionManager.isLoggedIn();
  
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Club France',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat',
      ),
      home: const WelcomePage(), // ✅ CAMBIAR a WelcomePage
    );
  }
}