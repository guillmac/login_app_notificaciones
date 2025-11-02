import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sport_activity.dart';
import 'package:flutter/foundation.dart';

class SportService {
  static const String baseUrl = 'https://clubfrance.org.mx';
  static const String mainEndpoint = '$baseUrl/api/deportes_endpoint.php';

  static Future<List<SportActivity>> getActividadesDeportivas() async {
    try {
      if (kDebugMode) {
        debugPrint('🚀 Conectando a: $mainEndpoint');
      }
      
      final response = await http.get(
        Uri.parse(mainEndpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('📡 Status Code: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        
        if (kDebugMode) {
          debugPrint('✅ Conexión exitosa con el servidor');
          debugPrint('📊 Total de actividades: ${jsonResponse['total']}');
          debugPrint('📋 Success: ${jsonResponse['success']}');
        }
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          if (kDebugMode) {
            debugPrint('🎯 Número de actividades en data: ${data.length}');
          }
          
          // Debug: mostrar información del primer elemento
          if (data.isNotEmpty && kDebugMode) {
            final primerElemento = data[0];
            debugPrint('🔍 Primer elemento del JSON:');
            debugPrint('   ID: ${primerElemento['id']}');
            debugPrint('   Nombre: ${primerElemento['nombre_actividad']}');
            debugPrint('   Categoría: ${primerElemento['categoria']}');
            
            // Mostrar información de días del primer elemento
            debugPrint('   Días encontrados (dia1-dia7):');
            for (int i = 1; i <= 7; i++) {
              final dia = primerElemento['dia$i']?.toString();
              debugPrint('     dia$i: "$dia" (tipo: ${dia?.runtimeType})');
            }
          }
          
          final actividades = data.map((json) {
            try {
              return SportActivity.fromJson(json);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('❌ Error parseando actividad: $e');
                debugPrint('   JSON problemático: $json');
              }
              // Retornar una actividad por defecto en caso de error
              return SportActivity(
                id: 0,
                nombreActividad: 'Error cargando actividad',
                lugar: '',
                edad: '',
                nombreProfesor: '',
                categoria: '',
                status: '',
                avisos: '',
                grupos: [],
                horarios: [],
                costosMensuales: [],
                diasSemana: [],
              );
            }
          }).toList();
          
          // Filtrar actividades válidas (excluyendo las que tuvieron error)
          final actividadesValidas = actividades.where((a) => a.id != 0).toList();
          
          // Log para debugging de días
          if (kDebugMode) {
            debugPrint('📅 RESUMEN DE DÍAS:');
            for (int i = 0; i < actividadesValidas.length && i < 3; i++) {
              final actividad = actividadesValidas[i];
              debugPrint('   ${actividad.nombreActividad}:');
              debugPrint('     - Días procesados: ${actividad.diasSemana}');
              debugPrint('     - Días formateados: "${actividad.diasFormateados}"');
            }
            
            // Estadísticas
            final infantiles = actividadesValidas.where((a) => a.isInfantil).length;
            final adultos = actividadesValidas.where((a) => a.isAdulto).length;
            final conDias = actividadesValidas.where((a) => a.tieneDias).length;
            
            debugPrint('👶 Actividades Infantiles: $infantiles');
            debugPrint('👨 Actividades Adultos: $adultos');
            debugPrint('📅 Actividades con días: $conDias');
            debugPrint('🎯 Total de actividades cargadas: ${actividadesValidas.length}');
          }
          
          return actividadesValidas;
        } else {
          throw Exception('Error del servidor: ${jsonResponse['error']}');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error conectando al servidor: $e');
        debugPrint('🔄 Usando datos de ejemplo...');
      }
      return await _getDatosEjemplo();
    }
  }

  static Future<List<SportActivity>> _getDatosEjemplo() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      SportActivity(
        id: 1,
        nombreActividad: "Fútbol Infantil (Modo Demo)",
        lugar: "Cancha Principal",
        edad: "Niños 6-12 años",
        nombreProfesor: "Prof. Juan Pérez",
        categoria: "Infantiles",
        status: "activo",
        avisos: "Traer ropa deportiva y agua",
        grupos: ["Grupo A: 6-8 años", "Grupo B: 9-12 años"],
        horarios: ["16:00-17:30", "17:30-19:00"],
        costosMensuales: ["\$500", "\$450"],
        diasSemana: ["Lunes", "Miércoles", "Viernes"],
      ),
      SportActivity(
        id: 2,
        nombreActividad: "Natación Adultos (Modo Demo)",
        lugar: "Alberca Olímpica",
        edad: "Adultos 18+ años",
        nombreProfesor: "Prof. María García",
        categoria: "Adultos",
        status: "activo",
        avisos: "Traer traje de baño y toalla",
        grupos: ["Principiantes", "Intermedios", "Avanzados"],
        horarios: ["07:00-08:30", "19:00-20:30", "20:30-22:00"],
        costosMensuales: ["\$600", "\$550", "\$700"],
        diasSemana: ["Martes", "Jueves"],
      ),
    ];
  }
}