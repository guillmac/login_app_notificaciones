import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cultural_activity.dart';
import 'package:flutter/foundation.dart';

class CulturalService {
  static const String baseUrl = 'https://clubfrance.org.mx';
  static const String mainEndpoint = '$baseUrl/api/cultural_endpoint.php';

  static Future<List<CulturalActivity>> getActividadesCulturales() async {
    try {
      if (kDebugMode) {
        debugPrint('🎭 === INICIANDO CARGA ACTIVIDADES CULTURALES ===');
        debugPrint('🎭 Conectando a: $mainEndpoint');
      }
      
      final response = await http.get(
        Uri.parse(mainEndpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('🎭 Status Code: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        
        if (kDebugMode) {
          debugPrint('🎭 ✅ Conexión exitosa con el servidor');
          debugPrint('🎭 📊 Total de actividades: ${jsonResponse['total']}');
          debugPrint('🎭 📋 Success: ${jsonResponse['success']}');
        }
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          if (kDebugMode) {
            debugPrint('🎭 🎯 Número de actividades culturales en data: ${data.length}');
          }
          
          // Debug: mostrar información detallada del primer elemento
          if (data.isNotEmpty && kDebugMode) {
            final primerElemento = data[0];
            debugPrint('🎭 🔍 Primer elemento cultural del JSON:');
            debugPrint('🎭    ID: ${primerElemento['id']}');
            debugPrint('🎭    Nombre: ${primerElemento['nombre_actividad']}');
            debugPrint('🎭    Categoría: ${primerElemento['categoria']}');
            debugPrint('🎭    Lugar: ${primerElemento['lugar']}');
            debugPrint('🎭    Profesor: ${primerElemento['profesor']}');
            debugPrint('🎭    Status: ${primerElemento['status']}');
            
            // Mostrar información de días del primer elemento
            debugPrint('🎭    Días encontrados (dia1-dia7):');
            for (int i = 1; i <= 7; i++) {
              final dia = primerElemento['dia$i']?.toString();
              debugPrint('🎭      dia$i: "$dia"');
            }
            
            // Mostrar información de horarios del primer elemento
            debugPrint('🎭    Horarios encontrados:');
            for (int i = 1; i <= 5; i++) {
              final horario = primerElemento['horario_grupo$i']?.toString();
              if (horario != null && horario.isNotEmpty && horario != 'null') {
                debugPrint('🎭      horario_grupo$i: "$horario"');
              }
            }
          } else if (kDebugMode) {
            debugPrint('🎭 ⚠️  No hay actividades culturales en la base de datos');
          }
          
          final actividades = data.map((json) {
            try {
              return CulturalActivity.fromJson(json);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('🎭 ❌ Error parseando actividad cultural: $e');
                debugPrint('🎭    JSON problemático: $json');
              }
              // Retornar una actividad por defecto en caso de error
              return CulturalActivity(
                id: 0,
                nombreActividad: 'Error cargando actividad cultural',
                lugar: '',
                profesor: '',
                celular: '',
                horario: '',
                avisos: '',
                facebook: '',
                categoria: '',
                status: '',
                grupos: [],
                horarios: [],
                diasSemana: [],
              );
            }
          }).toList();
          
          // Filtrar actividades válidas (excluyendo las que tuvieron error)
          final actividadesValidas = actividades.where((a) => a.id != 0).toList();
          
          // Log para debugging de días
          if (kDebugMode) {
            debugPrint('🎭 📅 RESUMEN DE ACTIVIDADES CULTURALES:');
            for (int i = 0; i < actividadesValidas.length && i < 3; i++) {
              final actividad = actividadesValidas[i];
              debugPrint('🎭    ${i + 1}. ${actividad.nombreActividad}');
              debugPrint('🎭       - Categoría: ${actividad.categoria}');
              debugPrint('🎭       - Días procesados: ${actividad.diasSemana}');
              debugPrint('🎭       - Días formateados: "${actividad.diasFormateados}"');
              debugPrint('🎭       - Horarios: ${actividad.horarios}');
              debugPrint('🎭       - Tiene días: ${actividad.tieneDias}');
              debugPrint('🎭       - Tiene horarios: ${actividad.tieneHorarios}');
            }
            
            // Estadísticas
            final infantiles = actividadesValidas.where((a) => a.isInfantil).length;
            final adultos = actividadesValidas.where((a) => a.isAdulto).length;
            final conDias = actividadesValidas.where((a) => a.tieneDias).length;
            final conHorarios = actividadesValidas.where((a) => a.tieneHorarios).length;
            
            debugPrint('🎭 📊 ESTADÍSTICAS CULTURALES:');
            debugPrint('🎭    👶 Infantiles: $infantiles');
            debugPrint('🎭    👨 Adultos: $adultos');
            debugPrint('🎭    📅 Con días: $conDias');
            debugPrint('🎭    ⏰ Con horarios: $conHorarios');
            debugPrint('🎭    🎯 Total cargadas: ${actividadesValidas.length}');
            debugPrint('🎭 === CARGA CULTURAL COMPLETADA ===');
          }
          
          return actividadesValidas;
        } else {
          if (kDebugMode) {
            debugPrint('🎭 ❌ Error del servidor: ${jsonResponse['error']}');
          }
          throw Exception('Error del servidor: ${jsonResponse['error']}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('🎭 ❌ Error HTTP: ${response.statusCode}');
        }
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🎭 ❌ Error crítico conectando al servidor: $e');
        debugPrint('🎭 🔄 Usando datos de ejemplo culturales...');
      }
      return await _getDatosEjemplo();
    }
  }

  static Future<List<CulturalActivity>> _getDatosEjemplo() async {
    await Future.delayed(const Duration(seconds: 1));
    
    if (kDebugMode) {
      debugPrint('🎭 🎨 Cargando datos de ejemplo culturales...');
    }
    
    return [
      CulturalActivity(
        id: 1,
        nombreActividad: "Pintura Infantil (Modo Demo)",
        lugar: "Sala de Arte",
        profesor: "Prof. Ana Martínez",
        celular: "555-1234",
        horario: "16:00-18:00",
        avisos: "Traer material de pintura",
        facebook: "ArteClubFrance",
        categoria: "Infantiles",
        status: "activo",
        grupos: ["Grupo A: 6-9 años", "Grupo B: 10-12 años"],
        horarios: ["16:00-17:00", "17:00-18:00"],
        diasSemana: ["Lunes", "Miércoles"],
      ),
      CulturalActivity(
        id: 2,
        nombreActividad: "Teatro Adultos (Modo Demo)",
        lugar: "Auditorio Principal",
        profesor: "Prof. Carlos López",
        celular: "555-5678",
        horario: "19:00-21:00",
        avisos: "Vestimenta cómoda",
        facebook: "TeatroCF",
        categoria: "Adultos",
        status: "activo",
        grupos: ["Principiantes", "Avanzados"],
        horarios: ["19:00-20:00", "20:00-21:00"],
        diasSemana: ["Martes", "Jueves"],
      ),
    ];
  }
}