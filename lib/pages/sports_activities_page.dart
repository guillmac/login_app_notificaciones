import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sport_activity.dart';
import '../services/sport_service.dart';
import '../services/reservation_service.dart';
import '../utils/session_manager.dart';

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
  final String _usuarioId = '1';
  List<Map<String, dynamic>> _integrantesFamilia = [];
  bool _loadingFamilia = true;

  @override
  void initState() {
    super.initState();
    _futureDeportivas = _loadActividadesDeportivas();
    _loadUserData();
    _loadClasesMuestraActivas();
  }

  Future<void> _loadUserData() async {
    setState(() => _loadingFamilia = true);
    
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData != null) {
        await _loadIntegrantesFamilia(userData['numero_usuario'] ?? '');
      } else {
        _setDefaultUserData();
      }
    } catch (e) {
      _setDefaultUserData();
    } finally {
      setState(() => _loadingFamilia = false);
    }
  }

  void _setDefaultUserData() {
    setState(() {
      _integrantesFamilia = [];
    });
  }

  // Cargar clases muestra activas desde la base de datos
  Future<void> _loadClasesMuestraActivas() async {
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData != null) {
        final numeroUsuario = userData['numero_usuario'] ?? '';
        final response = await http.post(
          Uri.parse("https://clubfrance.org.mx/api/get_clases_muestra.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"numero_usuario": numeroUsuario}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['clases_muestra'] != null) {
            final List<dynamic> clasesData = data['clases_muestra'];
            setState(() {
              _clasesMuestraActivas.clear();
              for (var clase in clasesData) {
                final claseMap = Map<String, dynamic>.from(clase);
                final actividadId = claseMap['actividad_id']?.toString() ?? '';
                if (actividadId.isNotEmpty) {
                  _clasesMuestraActivas[actividadId] = {
                    'integrante': claseMap['numero_usuario_integrante']?.toString() ?? '',
                    'dia': claseMap['dia_seleccionado']?.toString(),
                    'horario': claseMap['horario_seleccionado']?.toString(),
                    'fechaAsignacion': DateTime.parse(claseMap['fecha_registro'] ?? DateTime.now().toString()),
                    'id_reserva': claseMap['id']?.toString(),
                  };
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error al cargar clases muestra: $e');
    }
  }

  Future<void> _loadIntegrantesFamilia(String numeroUsuarioBase) async {
    if (numeroUsuarioBase.isEmpty || numeroUsuarioBase == 'No disponible') {
      setState(() {
        _integrantesFamilia = [];
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_usuarios_relacionados.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario_base": numeroUsuarioBase}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['usuarios_relacionados'] != null) {
          final List<dynamic> usuariosData = data['usuarios_relacionados'];
          List<Map<String, dynamic>> integrantes = [];
          
          for (var usuario in usuariosData) {
            if (usuario is Map) {
              final usuarioMap = Map<String, dynamic>.from(usuario);
              
              // Extraer primer_nombre y primer_apellido directamente del mapa
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
          
          setState(() {
            _integrantesFamilia = integrantes;
          });
        } else {
          await _loadInfoUsuarioActual(numeroUsuarioBase);
        }
      } else {
        await _loadInfoUsuarioActual(numeroUsuarioBase);
      }
    } catch (e) {
      await _loadInfoUsuarioActual(numeroUsuarioBase);
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
        Uri.parse("https://clubfrance.org.mx/api/get_usuario_info.php"), // ✅ CORREGIDO
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      );

      if (response.statusCode == 200) {
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
        } else {
          _setIntegrantePorDefecto(numeroUsuario);
        }
      } else {
        _setIntegrantePorDefecto(numeroUsuario);
      }
    } catch (e) {
      print('Error en _loadInfoUsuarioActual: $e');
      _setIntegrantePorDefecto(numeroUsuario);
    }
  }

  void _setIntegrantePorDefecto(String numeroUsuario) {
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
      
      _actividadesInfantiles = actividades.where((a) => a.isInfantil).toList();
      _actividadesAdultos = actividades.where((a) => a.isAdulto).toList();
      
      return actividades;
    } catch (e) {
      print('Error detallado en _loadActividadesDeportivas: $e');
      throw Exception('Error al cargar actividades: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _futureDeportivas = _loadActividadesDeportivas();
      _loadClasesMuestraActivas();
    });
  }

  void _handleClaseMuestra(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    
    if (!_clasesMuestraActivas.containsKey(actividadId)) {
      _mostrarFormularioClaseMuestra(actividad);
    }
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
                  // Header
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

                  // Contenido
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información de la actividad
                          _buildActivityInfoCard(actividad),

                          const SizedBox(height: 24),

                          // Selector de integrante
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

                  // Botones
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
                color: Colors.black.withOpacity(0.05),
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
            value: selectedValue,
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
              
              // Crear el texto en una sola línea: "PrimerNombre PrimerApellido - NumeroUsuario - Rol"
              String displayText = '';
              if (primerNombre.isNotEmpty && primerApellido.isNotEmpty) {
                displayText = '$primerNombre $primerApellido - $numeroUsuario - $rolDisplay';
              } else {
                // Fallback si no hay nombre y apellido
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
                color: Colors.black.withOpacity(0.05),
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
            value: selectedValue,
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
                color: Colors.black.withOpacity(0.05),
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
            value: selectedValue,
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
        _mostrarErrorSnackBar('No se pudo obtener la información del usuario');
        return;
      }

      final numeroUsuarioBase = userData['numero_usuario'] ?? '';

      // Guardar en la base de datos
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
        if (data['success'] == true) {
          setState(() {
            _clasesMuestraActivas[actividadId] = {
              'integrante': integrante,
              'dia': diaSeleccionado,
              'horario': horarioSeleccionado,
              'fechaAsignacion': DateTime.now(),
              'id_reserva': data['id_reserva']?.toString(),
            };
          });

          _mostrarConfirmacionSnackBar(actividad, integrante, diaSeleccionado, horarioSeleccionado);
        } else {
          _mostrarErrorSnackBar(data['message'] ?? 'Error al guardar la clase muestra');
        }
      } else {
        _mostrarErrorSnackBar('Error de conexión al servidor');
      }
    } catch (e) {
      _mostrarErrorSnackBar('Error: $e');
    }
  }

  void _mostrarConfirmacionSnackBar(
    SportActivity actividad, 
    String integrante, 
    String? diaSeleccionado, 
    String? horarioSeleccionado
  ) {
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

  void _mostrarErrorSnackBar(String mensaje) {
    // Verificar si es error de endpoint
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

  void _cancelarClaseMuestra(SportActivity actividad) async {
    final actividadId = actividad.id.toString();
    final infoClase = _clasesMuestraActivas[actividadId];
    
    if (infoClase == null) return;

    final confirmarCancelacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar clase muestra'),
        content: Text(
          '¿Estás seguro de que deseas cancelar la clase muestra de "${actividad.nombreActividad}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmarCancelacion != true) return;

    try {
      final idReserva = infoClase['id_reserva']?.toString();
      if (idReserva == null) {
        _mostrarErrorSnackBar('No se pudo identificar la reserva para cancelar');
        return;
      }

      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/cancelar_clase_muestra.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_reserva": idReserva,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _clasesMuestraActivas.remove(actividadId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Clase muestra cancelada para ${actividad.nombreActividad}"),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          _mostrarErrorSnackBar(data['message'] ?? "Error al cancelar la clase muestra");
        }
      } else {
        _mostrarErrorSnackBar('Error de conexión al servidor');
      }
    } catch (e) {
      _mostrarErrorSnackBar('Error: $e');
    }
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
      body: FutureBuilder<List<SportActivity>>(
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
    final tieneClaseMuestra = _clasesMuestraActivas.containsKey(actividadId);
    final infoClaseMuestra = tieneClaseMuestra ? _clasesMuestraActivas[actividadId] : null;

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
                    color: color.withOpacity(0.1),
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
            
            if (tieneClaseMuestra)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Clase muestra programada",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                          onPressed: () => _cancelarClaseMuestra(actividad),
                          tooltip: "Cancelar clase muestra",
                        ),
                      ],
                    ),
                    if (infoClaseMuestra != null) ...[
                      const SizedBox(height: 8),
                      if (infoClaseMuestra['dia'] != null)
                        Text(
                          '📅 Día: ${infoClaseMuestra['dia']}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      if (infoClaseMuestra['horario'] != null)
                        Text(
                          '⏰ Horario: ${infoClaseMuestra['horario']}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                    ],
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () => _handleClaseMuestra(actividad),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tieneClaseMuestra 
                      ? Colors.grey
                      : const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  tieneClaseMuestra ? Icons.check_circle : Icons.school,
                  size: 20,
                ),
                label: Text(
                  tieneClaseMuestra ? "CLASE MUESTRA PROGRAMADA" : "SOLICITAR CLASE MUESTRA",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
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
              backgroundColor: Colors.blue.withOpacity(0.1),
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
            backgroundColor: Colors.green.withOpacity(0.1),
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
            color: Colors.orange.withOpacity(0.1),
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
      return 'Error: $error';
    }
  }
}