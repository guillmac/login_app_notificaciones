import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/sport_activity.dart';
import '../services/sport_service.dart';
import '../services/payment_service.dart';
import '../utils/session_manager.dart';
import '../pages/payment_screen.dart';
import 'mis_clases_page.dart';

class SportsActivitiesPage extends StatefulWidget {
  const SportsActivitiesPage({super.key});

  @override
  State<SportsActivitiesPage> createState() => _SportsActivitiesPageState();
}

class _SportsActivitiesPageState extends State<SportsActivitiesPage> {
  late Future<List<SportActivity>> _futureDeportivas;
  List<SportActivity> _actividadesInfantiles = [];
  List<SportActivity> _actividadesAdultos = [];
  final Map<String, Map<String, dynamic>> _clasesMuestraActivas = {};
  List<Map<String, dynamic>> _integrantesFamilia = [];
  bool _loadingFamilia = true;
  bool _isLoadingClasesData = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoadingClasesData = true;
    });
    
    try {
      await _loadUserData();
      _futureDeportivas = _loadActividadesDeportivas();
      await _loadClasesMuestraActivas();
    } catch (e) {
      print('Error inicializando datos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClasesData = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _loadingFamilia = true);
    
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData != null && mounted) {
        await _loadIntegrantesFamilia(userData['numero_usuario'] ?? '');
      } else if (mounted) {
        _setDefaultUserData();
      }
    } catch (e) {
      if (mounted) {
        _setDefaultUserData();
      }
    } finally {
      if (mounted) {
        setState(() => _loadingFamilia = false);
      }
    }
  }

  void _setDefaultUserData() {
    if (!mounted) return;
    setState(() {
      _integrantesFamilia = [];
    });
  }

  Future<void> _loadClasesMuestraActivas() async {
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData == null || !mounted) return;

      final numeroUsuario = userData['numero_usuario'] ?? '';
      if (numeroUsuario.isEmpty) return;

      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_clases_muestra.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final clasesData = data['clases_muestra'] ?? [];
          final Map<String, Map<String, dynamic>> nuevasClases = {};
          
          for (var clase in clasesData) {
            final claseMap = Map<String, dynamic>.from(clase);
            final actividadId = claseMap['actividad_id']?.toString() ?? '';
            if (actividadId.isNotEmpty) {
              nuevasClases[actividadId] = {
                'integrante': claseMap['numero_usuario_integrante']?.toString() ?? '',
                'dia': claseMap['dia_seleccionado']?.toString(),
                'horario': claseMap['horario_seleccionado']?.toString(),
                'fechaAsignacion': DateTime.parse(claseMap['fecha_registro'] ?? DateTime.now().toString()),
                'id_reserva': claseMap['id_reserva']?.toString() ?? claseMap['id']?.toString(),
                'estado': claseMap['estado']?.toString() ?? 'asignada',
              };
            }
          }
          
          // CARGAR TAMBIÉN CLASES TOMADAS
          await _loadClasesTomadas(numeroUsuario, nuevasClases);
          
          if (mounted) {
            setState(() {
              _clasesMuestraActivas.clear();
              _clasesMuestraActivas.addAll(nuevasClases);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _clasesMuestraActivas.clear();
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _clasesMuestraActivas.clear();
          });
        }
      }
    } catch (e) {
      print('Error cargando clases muestra: $e');
      if (mounted) {
        setState(() {
          _clasesMuestraActivas.clear();
        });
      }
    }
  }

  Future<void> _loadClasesTomadas(String numeroUsuario, Map<String, Map<String, dynamic>> clasesMap) async {
    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_clases_tomadas.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['clases_tomadas'] != null) {
          final clasesTomadasData = data['clases_tomadas'] as Map<String, dynamic>;
          
          clasesTomadasData.forEach((actividadId, claseData) {
            if (clasesMap.containsKey(actividadId)) {
              clasesMap[actividadId]!['estado'] = 'tomada';
            } else {
              final claseMap = Map<String, dynamic>.from(claseData);
              clasesMap[actividadId] = {
                'integrante': numeroUsuario,
                'dia': null,
                'horario': null,
                'fechaAsignacion': DateTime.parse(claseMap['fecha_registro'] ?? DateTime.now().toString()),
                'id_reserva': claseMap['id_reserva']?.toString() ?? claseMap['id']?.toString(),
                'estado': 'tomada',
              };
            }
          });
        }
      }
    } catch (e) {
      print('Error cargando clases tomadas: $e');
    }
  }

  String _getEstadoClase(String actividadId) {
    if (_clasesMuestraActivas.containsKey(actividadId)) {
      final estado = _clasesMuestraActivas[actividadId]!['estado']?.toString().toLowerCase() ?? 'asignada';
      return estado;
    }
    return 'no_solicitada';
  }

  // NUEVOS MÉTODOS PARA MANEJAR ESTADOS
  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'asignada':
        return Colors.orange;
      case 'tomada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'asignada':
        return Icons.schedule;
      case 'tomada':
        return Icons.check_circle;
      case 'cancelada':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getTextForEstado(String estado) {
    switch (estado) {
      case 'asignada':
        return "Clase muestra asignada";
      case 'tomada':
        return "Clase muestra completada";
      case 'cancelada':
        return "Clase muestra cancelada";
      default:
        return "Estado no disponible";
    }
  }

  // MÉTODO PRINCIPAL PARA CONSTRUIR BOTÓN SEGÚN ESTADO
  Widget _buildBotonPorEstado(SportActivity actividad, String estado) {
    switch (estado) {
      case 'asignada':
        return _buildBotonClaseEnProceso(actividad);
      case 'tomada':
        return _buildBotonPagar(actividad);
      case 'cancelada':
      case 'no_solicitada':
      default:
        return _buildBotonTomarClaseMuestra(actividad);
    }
  }

  // BOTÓN POR DEFECTO - TOMAR CLASE MUESTRA
  Widget _buildBotonTomarClaseMuestra(SportActivity actividad) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () => _handleClaseMuestra(actividad),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.school, size: 20),
        label: const Text(
          "TOMAR CLASE MUESTRA",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // BOTÓN PARA ESTADO "ASIGNADA" - CLASE MUESTRA EN PROCESO (SIN BOTÓN DE CANCELAR)
  Widget _buildBotonClaseEnProceso(SportActivity actividad) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () {
          _mostrarDetallesClaseProgramada(actividad);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.calendar_today, size: 20),
        label: const Text(
          "CLASE MUESTRA EN PROCESO",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // BOTÓN PARA ESTADO "TOMADA" - PAGAR
  Widget _buildBotonPagar(SportActivity actividad) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () => _handlePagoActividad(actividad),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.payment, size: 20),
        label: const Text(
          "PAGAR ACADEMIA",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _handleClaseMuestra(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    final estadoClase = _getEstadoClase(actividadId);
    
    // Permitir solicitar clase muestra solo si no está asignada o está cancelada
    if (estadoClase == 'no_solicitada' || estadoClase == 'cancelada') {
      _mostrarFormularioClaseMuestra(actividad);
    } else if (estadoClase == 'asignada') {
      _mostrarInfoSnackBar('Ya tienes una clase muestra en proceso para esta actividad.');
    } else if (estadoClase == 'tomada') {
      _mostrarInfoSnackBar('Ya has tomado la clase muestra de esta actividad.');
    }
  }

  Future<void> _loadIntegrantesFamilia(String numeroUsuarioBase) async {
    if (numeroUsuarioBase.isEmpty || numeroUsuarioBase == 'No disponible') {
      if (mounted) {
        setState(() {
          _integrantesFamilia = [];
        });
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_usuarios_relacionados.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario_base": numeroUsuarioBase}),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['usuarios_relacionados'] != null) {
          final List<dynamic> usuariosData = data['usuarios_relacionados'];
          List<Map<String, dynamic>> integrantes = [];
          
          for (var usuario in usuariosData) {
            if (usuario is Map) {
              final usuarioMap = Map<String, dynamic>.from(usuario);
              
              String primerNombre = usuarioMap['primer_nombre']?.toString() ?? '';
              String primerApellido = usuarioMap['primer_apellido']?.toString() ?? '';
              String nombreCompleto = _obtenerNombreCompletoDeUsuario(usuarioMap);
              
              integrantes.add({
                'numero_usuario': usuarioMap['numero_usuario']?.toString() ?? usuarioMap['id']?.toString() ?? 'N/A',
                'nombre': nombreCompleto,
                'primer_nombre': primerNombre,
                'primer_apellido': primerApellido,
                'rol': usuarioMap['rol']?.toString() ?? _determinarRol(usuarioMap['numero_usuario']?.toString() ?? ''),
              });
            }
          }
          
          if (mounted) {
            setState(() {
              _integrantesFamilia = integrantes;
            });
          }
        } else if (mounted) {
          await _loadInfoUsuarioActual(numeroUsuarioBase);
        }
      } else if (mounted) {
        await _loadInfoUsuarioActual(numeroUsuarioBase);
      }
    } catch (e) {
      if (mounted) {
        await _loadInfoUsuarioActual(numeroUsuarioBase);
      }
    }
  }

  String _obtenerNombreCompletoDeUsuario(Map<String, dynamic> usuario) {
    String nombreCompleto = usuario['nombre_completo']?.toString() ?? 
                           usuario['nombre']?.toString() ?? 
                           usuario['name']?.toString() ?? 
                           usuario['full_name']?.toString() ?? 
                           '';

    if (nombreCompleto.isEmpty) {
      String nombre = usuario['nombre']?.toString() ?? 
                     usuario['primer_nombre']?.toString() ?? 
                     usuario['first_name']?.toString() ?? '';
      
      String apellidoPaterno = usuario['apellido_paterno']?.toString() ?? 
                              usuario['apellido']?.toString() ?? 
                              usuario['last_name']?.toString() ?? '';
      
      String apellidoMaterno = usuario['apellido_materno']?.toString() ?? 
                              usuario['segundo_apellido']?.toString() ?? '';

      if (nombre.isNotEmpty && apellidoPaterno.isNotEmpty) {
        nombreCompleto = '$nombre $apellidoPaterno ${apellidoMaterno.isNotEmpty ? apellidoMaterno : ''}'.trim();
      } else if (nombre.isNotEmpty) {
        nombreCompleto = nombre;
      }
    }

    if (nombreCompleto.isEmpty) {
      final numeroUsuario = usuario['numero_usuario']?.toString() ?? '';
      final rol = _determinarRol(numeroUsuario);
      nombreCompleto = _obtenerNombrePorRol(rol);
    }

    return nombreCompleto;
  }

  String _obtenerNombrePorRol(String rol) {
    switch (rol) {
      case 'titular': return 'Titular';
      case 'conyuge': return 'Cónyuge';
      case 'hijo': return 'Hijo/a';
      default: return 'Miembro Familiar';
    }
  }

  Future<void> _loadInfoUsuarioActual(String numeroUsuario) async {
    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_usuario_info.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final dataMap = Map<String, dynamic>.from(data);
          
          String nombreCompleto = _obtenerNombreCompletoDeUsuario(dataMap);
          String primerNombre = dataMap['primer_nombre']?.toString() ?? '';
          String primerApellido = dataMap['primer_apellido']?.toString() ?? '';
          
          setState(() {
            _integrantesFamilia = [{
              'numero_usuario': dataMap['numero_usuario']?.toString() ?? numeroUsuario,
              'nombre': nombreCompleto,
              'primer_nombre': primerNombre,
              'primer_apellido': primerApellido,
              'rol': 'titular',
            }];
          });
        } else if (mounted) {
          _setIntegrantePorDefecto(numeroUsuario);
        }
      } else if (mounted) {
        _setIntegrantePorDefecto(numeroUsuario);
      }
    } catch (e) {
      if (mounted) {
        _setIntegrantePorDefecto(numeroUsuario);
      }
    }
  }

  void _setIntegrantePorDefecto(String numeroUsuario) {
    if (!mounted) return;
    setState(() {
      _integrantesFamilia = [{
        'numero_usuario': numeroUsuario,
        'nombre': 'Usuario Principal',
        'primer_nombre': 'Usuario',
        'primer_apellido': 'Principal',
        'rol': 'titular',
      }];
    });
  }

  String _determinarRol(String numeroUsuario) {
    if (numeroUsuario.isEmpty) return 'titular';
    if (!numeroUsuario.contains(RegExp(r'[A-Z]$'))) return 'titular';
    
    final sufijo = numeroUsuario.substring(numeroUsuario.length - 1);
    switch (sufijo) {
      case 'A': return 'conyuge';
      case 'B': return 'hijo';
      case 'C': return 'hijo';
      case 'D': return 'hijo';
      case 'E': return 'hijo';
      default: return 'hijo';
    }
  }

  String _getRolDisplay(String rol) {
    switch (rol) {
      case 'titular': return 'Titular';
      case 'conyuge': return 'Cónyuge';
      case 'hijo': return 'Hijo/a';
      default: return 'Miembro';
    }
  }

  Color _getColorRol(String rol) {
    switch (rol) {
      case 'titular': return const Color(0xFF1565C0);
      case 'conyuge': return const Color(0xFF7B1FA2);
      case 'hijo': return const Color(0xFF2E7D32);
      default: return Colors.grey;
    }
  }

  List<String> _extraerDiasDisponibles(SportActivity actividad) {
    final List<String> todosDias = [];
    
    if (actividad.tieneDias && actividad.diasFormateados.isNotEmpty) {
      final diasSeparados = actividad.diasFormateados.split(',').map((d) => d.trim()).toList();
      todosDias.addAll(diasSeparados);
    }
    
    return todosDias.where((dia) => dia.isNotEmpty).toSet().toList();
  }

  List<String> _extraerHorariosDisponibles(SportActivity actividad) {
    final List<String> todosHorarios = [];
    
    if (actividad.horarios.isNotEmpty) {
      for (String horarioCompleto in actividad.horarios) {
        if (horarioCompleto.contains(',')) {
          final horariosSeparados = horarioCompleto.split(',').map((h) => h.trim()).toList();
          todosHorarios.addAll(horariosSeparados);
        } else {
          todosHorarios.add(horarioCompleto.trim());
        }
      }
    }
    
    return todosHorarios.where((horario) => horario.isNotEmpty).toSet().toList();
  }

  Future<List<SportActivity>> _loadActividadesDeportivas() async {
    try {
      final actividades = await SportService.getActividadesDeportivas();
      
      if (mounted) {
        setState(() {
          _actividadesInfantiles = actividades.where((a) => a.isInfantil).toList();
          _actividadesAdultos = actividades.where((a) => a.isAdulto).toList();
        });
      }
      
      return actividades;
    } catch (e) {
      throw Exception('Error al cargar actividades deportivas');
    }
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _isLoadingClasesData = true;
    });
    
    _initializeData().then((_) {
      if (mounted) {
        setState(() {
          _isLoadingClasesData = false;
        });
      }
    });
  }

  void _mostrarFormularioClaseMuestra(SportActivity actividad) {
    final diasDisponibles = _extraerDiasDisponibles(actividad);
    final horariosDisponibles = _extraerHorariosDisponibles(actividad);

    String? integranteSeleccionado;
    String? diaSeleccionado;
    String? horarioSeleccionado;

    if (_integrantesFamilia.isNotEmpty) {
      integranteSeleccionado = _integrantesFamilia.first['numero_usuario'] as String?;
    }
    if (diasDisponibles.isNotEmpty) {
      diaSeleccionado = diasDisponibles.first;
    }
    if (horariosDisponibles.isNotEmpty) {
      horarioSeleccionado = horariosDisponibles.first;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 10,
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 600,
                maxHeight: 700,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clase muestra - ${actividad.nombreActividad}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActivityInfoCard(actividad),

                          const SizedBox(height: 24),

                          if (_loadingFamilia)
                            _buildLoadingWidget()
                          else if (_integrantesFamilia.isEmpty)
                            _buildNoIntegrantsWidget()
                          else
                            _buildIntegrantDropdown(
                              integranteSeleccionado,
                              (value) => setModalState(() {
                                integranteSeleccionado = value;
                              }),
                            ),

                          if (diasDisponibles.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildDayDropdown(
                              diasDisponibles,
                              diaSeleccionado,
                              (value) => setModalState(() {
                                diaSeleccionado = value;
                              }),
                            ),
                          ],

                          if (horariosDisponibles.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildTimeDropdown(
                              horariosDisponibles,
                              horarioSeleccionado,
                              (value) => setModalState(() {
                                horarioSeleccionado = value;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.grey[400]!),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (integranteSeleccionado != null && 
                                       (diasDisponibles.isEmpty || diaSeleccionado != null) &&
                                       (horariosDisponibles.isEmpty || horarioSeleccionado != null))
                                ? () {
                                    Navigator.pop(context);
                                    _asignarClaseMuestra(
                                      actividad: actividad,
                                      integrante: integranteSeleccionado!,
                                      diaSeleccionado: diaSeleccionado,
                                      horarioSeleccionado: horarioSeleccionado,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirmar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _asignarClaseMuestra({
    required SportActivity actividad,
    required String integrante,
    required String? diaSeleccionado,
    required String? horarioSeleccionado,
  }) async {
    final actividadId = actividad.id.toString();
    
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData == null) {
        if (mounted) {
          _mostrarErrorSnackBar('No se pudo obtener la información del usuario');
        }
        return;
      }

      final numeroUsuarioBase = userData['numero_usuario'] ?? '';

      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/guardar_clase_muestra.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "numero_usuario_base": numeroUsuarioBase,
          "numero_usuario_integrante": integrante,
          "actividad_id": actividadId,
          "actividad_nombre": actividad.nombreActividad,
          "profesor": actividad.nombreProfesor,
          "ubicacion": actividad.lugar,
          "dia_seleccionado": diaSeleccionado,
          "horario_seleccionado": horarioSeleccionado,
          "fecha_registro": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _clasesMuestraActivas[actividadId] = {
              'integrante': integrante,
              'dia': diaSeleccionado,
              'horario': horarioSeleccionado,
              'fechaAsignacion': DateTime.now(),
              'id_reserva': data['id_reserva']?.toString(),
              'estado': 'asignada',
            };
          });

          _mostrarConfirmacionSnackBar(actividad, integrante, diaSeleccionado, horarioSeleccionado);
        } else if (mounted) {
          _mostrarErrorSnackBar(data['message'] ?? 'Error al guardar la clase muestra');
        }
      } else if (mounted) {
        _mostrarErrorSnackBar('Error de conexión al servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _mostrarErrorSnackBar('Error al procesar la solicitud: $e');
      }
    }
  }

  void _mostrarConfirmacionSnackBar(
    SportActivity actividad, 
    String integrante, 
    String? diaSeleccionado, 
    String? horarioSeleccionado
  ) {
    if (!mounted) return;
    
    final integranteData = _integrantesFamilia.firstWhere(
      (i) => i['numero_usuario'] == integrante,
      orElse: () => {'nombre': integrante, 'rol': 'miembro'}
    );

    String mensaje = '✅ Clase muestra confirmada\n\n'
                    '👤 Para: ${integranteData['nombre']} ($integrante)\n'
                    '📋 Actividad: ${actividad.nombreActividad}\n'
                    '👨‍🏫 Profesor: ${actividad.nombreProfesor}\n'
                    '📍 Ubicación: ${actividad.lugar}\n';

    if (diaSeleccionado != null) {
      mensaje += '📅 Día: $diaSeleccionado\n';
    }

    if (horarioSeleccionado != null) {
      mensaje += '⏰ Horario: $horarioSeleccionado';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _mostrarDetallesClaseProgramada(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    final infoClase = _clasesMuestraActivas[actividadId];
    
    if (infoClase == null) return;

    String? integranteNombre = 'Usuario';
    if (infoClase['integrante'] != null) {
      final integrante = _integrantesFamilia.firstWhere(
        (i) => i['numero_usuario'] == infoClase['integrante'],
        orElse: () => {'nombre': infoClase['integrante']}
      );
      integranteNombre = integrante['nombre'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de Clase Programada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 Actividad: ${actividad.nombreActividad}'),
            Text('👤 Integrante: $integranteNombre'),
            Text('👨‍🏫 Profesor: ${actividad.nombreProfesor}'),
            Text('📍 Ubicación: ${actividad.lugar}'),
            if (infoClase['dia'] != null) 
              Text('📅 Día: ${infoClase['dia']}'),
            if (infoClase['horario'] != null) 
              Text('⏰ Horario: ${infoClase['horario']}'),
            if (infoClase['fechaAsignacion'] != null)
              Text('🗓️ Fecha de asignación: ${DateFormat('dd/MM/yyyy').format(infoClase['fechaAsignacion'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityInfoCard(SportActivity actividad) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: Color(0xFF1976D2), size: 18),
              SizedBox(width: 8),
              Text(
                'Información de la actividad',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityInfoRow(Icons.sports, 'Actividad:', actividad.nombreActividad),
          _buildActivityInfoRow(Icons.person, 'Profesor:', actividad.nombreProfesor),
          _buildActivityInfoRow(Icons.place, 'Ubicación:', actividad.lugar),
          if (actividad.tieneDias)
            _buildActivityInfoRow(Icons.calendar_today, 'Días:', actividad.diasFormateados),
          if (actividad.horarios.isNotEmpty)
            _buildActivityInfoRow(Icons.access_time, 'Horarios:', actividad.horarios.join(', ')),
        ],
      ),
    );
  }

  Widget _buildActivityInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'No disponible',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
          SizedBox(height: 12),
          Text(
            'Cargando integrantes...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoIntegrantsWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No se encontraron integrantes de la membresía',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrantDropdown(
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona integrante:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _getColorWithOpacity(Colors.black, 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            initialValue: selectedValue,
            selectedItemBuilder: (BuildContext context) {
              return _integrantesFamilia.map<Widget>((integrante) {
                final numeroUsuario = integrante['numero_usuario'] as String;
                final primerNombre = integrante['primer_nombre'] as String? ?? '';
                final primerApellido = integrante['primer_apellido'] as String? ?? '';
                final rol = integrante['rol'] as String;
                final rolDisplay = _getRolDisplay(rol);
                
                String displayText = '';
                if (primerNombre.isNotEmpty && primerApellido.isNotEmpty) {
                  displayText = '$primerNombre $primerApellido - $numeroUsuario - $rolDisplay';
                } else {
                  final nombreCompleto = integrante['nombre'] as String? ?? 'Usuario';
                  displayText = '$nombreCompleto - $numeroUsuario - $rolDisplay';
                }
                
                return Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
            items: _integrantesFamilia.map<DropdownMenuItem<String>>((integrante) {
              final numeroUsuario = integrante['numero_usuario'] as String;
              final primerNombre = integrante['primer_nombre'] as String? ?? '';
              final primerApellido = integrante['primer_apellido'] as String? ?? '';
              final rol = integrante['rol'] as String;
              final rolDisplay = _getRolDisplay(rol);
              final colorRol = _getColorRol(rol);
              
              String displayText = '';
              if (primerNombre.isNotEmpty && primerApellido.isNotEmpty) {
                displayText = '$primerNombre $primerApellido - $numeroUsuario - $rolDisplay';
              } else {
                final nombreCompleto = integrante['nombre'] as String? ?? 'Usuario';
                displayText = '$nombreCompleto - $numeroUsuario - $rolDisplay';
              }
              
              return DropdownMenuItem<String>(
                value: numeroUsuario,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorRol,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDayDropdown(
    List<String> diasDisponibles,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un día:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _getColorWithOpacity(Colors.black, 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
            ),
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            initialValue: selectedValue,
            items: diasDisponibles.map<DropdownMenuItem<String>>((dia) {
              return DropdownMenuItem<String>(
                value: dia,
                child: Text(
                  dia,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDropdown(
    List<String> horariosDisponibles,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un horario:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _getColorWithOpacity(Colors.black, 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.access_time, color: Color(0xFF2E7D32)),
            ),
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            initialValue: selectedValue,
            items: horariosDisponibles.map<DropdownMenuItem<String>>((horario) {
              return DropdownMenuItem<String>(
                value: horario,
                child: Text(
                  horario,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Actividades Deportivas",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Actualizar",
          ),
        ],
      ),
      body: _isLoadingClasesData 
          ? _buildLoadingClasesData()
          : FutureBuilder<List<SportActivity>>(
              future: _futureDeportivas,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildContent();
              },
            ),
    );
  }

  Widget _buildLoadingClasesData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            "Cargando información de clases...",
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            "Cargando actividades...",
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MisClasesPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.class_, size: 24),
                const SizedBox(width: 12),
                const Text(
                  "Mis Clases",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _getColorWithOpacity(Colors.black, 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const TabBar(
                    labelColor: Color(0xFF0D47A1),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF0D47A1),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.child_care),
                        text: 'INFANTILES',
                      ),
                      Tab(
                        icon: Icon(Icons.person),
                        text: 'ADULTOS',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListaActividades(_actividadesInfantiles, Colors.blue),
                      _buildListaActividades(_actividadesAdultos, Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaActividades(List<SportActivity> actividades, Color color) {
    if (actividades.isEmpty) {
      return _buildEmptyState("No hay actividades disponibles");
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadActividadesDeportivas();
        if (mounted) {
          setState(() {});
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: actividades.length,
        itemBuilder: (context, index) {
          return _buildTarjetaActividad(actividades[index], color);
        },
      ),
    );
  }

  Widget _buildTarjetaActividad(SportActivity actividad, Color color) {
    final actividadId = actividad.id.toString();
    final estadoClase = _getEstadoClase(actividadId);
    final infoClase = _clasesMuestraActivas[actividadId];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    actividad.nombreActividad,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getColorWithOpacity(color, 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actividad.categoria.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildInfoRow(Icons.person, actividad.nombreProfesor),
            _buildInfoRow(Icons.place, actividad.lugar),
            _buildInfoRow(Icons.people, actividad.edad),
            
            _buildDiasYHorarios(actividad),
            
            if (actividad.grupos.isNotEmpty && actividad.grupos.length > 1) 
              _buildGrupos(actividad),
            
            if (actividad.costosMensuales.isNotEmpty) ..._buildCostos(actividad),
            
            if (actividad.avisos.isNotEmpty) _buildAvisos(actividad),
            
            // SECCIÓN DE ESTADO DE CLASE MUESTRA - ACTUALIZADA
            if (estadoClase != 'no_solicitada')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _getColorForEstado(estadoClase).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getColorForEstado(estadoClase),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getIconForEstado(estadoClase),
                          color: _getColorForEstado(estadoClase),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getTextForEstado(estadoClase),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getColorForEstado(estadoClase),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (estadoClase == 'asignada' && infoClase != null) ...[
                      const SizedBox(height: 8),
                      if (infoClase['dia'] != null) 
                        Text('📅 Próximo: ${infoClase['dia']}'),
                      if (infoClase['horario'] != null) 
                        Text('⏰ Horario: ${infoClase['horario']}'),
                    ],
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // BOTONES ACTUALIZADOS SEGÚN ESTADO
            _buildBotonPorEstado(actividad, estadoClase),
          ],
        ),
      ),
    );
  }

  Widget _buildDiasYHorarios(SportActivity actividad) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (actividad.tieneDias)
                  Text(
                    actividad.diasFormateados,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (actividad.horarios.isNotEmpty)
                  ...actividad.horarios.map((horario) => Text(
                    horario,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  )),
                if (!actividad.tieneDias && actividad.horarios.isEmpty)
                  const Text(
                    'Horario por confirmar',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrupos(SportActivity actividad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          "Grupos Disponibles:",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: actividad.grupos.map((grupo) {
            return Chip(
              label: Text(
                grupo,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),
              backgroundColor: _getColorWithOpacity(Colors.blue, 0.1),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildCostos(SportActivity actividad) {
    return [
      const SizedBox(height: 8),
      const Text(
        "Costos Mensuales:",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: actividad.costosMensuales.map((costo) {
          return Chip(
            label: Text(
              costo,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
            backgroundColor: _getColorWithOpacity(Colors.green, 0.1),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildAvisos(SportActivity actividad) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getColorWithOpacity(Colors.orange, 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  actividad.avisos,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState([String message = "No hay actividades disponibles"]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Error de conexión",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getUserFriendlyError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text("Reintentar"),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserFriendlyError(String error) {
    if (error.contains('Failed host lookup') || error.contains('SocketException')) {
      return 'No se pudo conectar con el servidor. Verifica tu conexión a internet.';
    } else if (error.contains('timed out')) {
      return 'El servidor está tardando demasiado en responder. Intenta nuevamente.';
    } else if (error.contains('404')) {
      return 'El servicio no está disponible en este momento.';
    } else {
      return 'Error al cargar las actividades deportivas';
    }
  }

  void _handlePagoActividad(SportActivity actividad) async {
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData == null) {
        _mostrarErrorSnackBar('No se pudo obtener la información del usuario');
        return;
      }

      final numeroUsuario = userData['numero_usuario'] ?? '';
      final nombreUsuario = userData['primer_nombre'] ?? 'Usuario';
      final apellidoUsuario = userData['primer_apellido'] ?? '';

      final precio = _obtenerPrecioActividad(actividad);
      
      if (precio <= 0) {
        _mostrarErrorSnackBar('No se pudo determinar el precio de la actividad');
        return;
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Inscripción'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividad: ${actividad.nombreActividad}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Profesor: ${actividad.nombreProfesor}'),
              Text('Lugar: ${actividad.lugar}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Precio: \$$precio MXN',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿Deseas proceder con el pago de la inscripción?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
              ),
              child: const Text('Continuar al Pago'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      final paymentData = await PaymentService.generatePaymentData(
        actividadNombre: actividad.nombreActividad,
        actividadId: actividad.id.toString(),
        numeroUsuario: numeroUsuario,
        nombreUsuario: nombreUsuario,
        apellidoUsuario: apellidoUsuario,
        precio: precio,
        concepto: 'INSCRIPCION',
      );

      if (paymentData['success'] == true && mounted) {
        await PaymentService.savePaymentRecord(
          referencia: paymentData['referencia'],
          actividadId: actividad.id.toString(),
          actividadNombre: actividad.nombreActividad,
          numeroUsuario: numeroUsuario,
          nombreUsuario: '$nombreUsuario $apellidoUsuario',
          importe: precio,
        );

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(paymentData: paymentData),
          ),
        );

        if (result != null && result['success'] == true && mounted) {
          _mostrarExitoSnackBar('¡Inscripción pagada exitosamente!');
          _refreshData();
        } else if (result != null && result['cancelled'] == true) {
          _mostrarInfoSnackBar('Pago cancelado');
        } else if (mounted) {
          _mostrarErrorSnackBar('Error en el proceso de pago');
        }
      } else {
        _mostrarErrorSnackBar(paymentData['error'] ?? 'Error al generar el pago');
      }
    } catch (e) {
      _mostrarErrorSnackBar('Error al procesar el pago: $e');
    }
  }

  double _obtenerPrecioActividad(SportActivity actividad) {
    try {
      if (actividad.costosMensuales.isNotEmpty) {
        for (String costo in actividad.costosMensuales) {
          final regex = RegExp(r'(\$?\s*(\d+(?:\.\d+)?))');
          final matches = regex.allMatches(costo);
          
          for (final match in matches) {
            final priceStr = match.group(2);
            if (priceStr != null) {
              final price = double.tryParse(priceStr);
              if (price != null && price > 0) {
                return price;
              }
            }
          }
        }
      }
      
      if (actividad.isInfantil) {
        return 500.00;
      } else {
        return 800.00;
      }
    } catch (e) {
      return 0.0;
    }
  }

  void _mostrarExitoSnackBar(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ $mensaje',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarInfoSnackBar(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ℹ️ $mensaje',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarErrorSnackBar(String mensaje) {
    if (!mounted) return;
    
    if (mensaje.contains('404') || mensaje.contains('Not Found')) {
      mensaje = 'Servicio no encontrado. Verifica los endpoints.';
    } else if (mensaje.contains('500')) {
      mensaje = 'Error interno del servidor.';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '❌ $mensaje',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Color _getColorWithOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}