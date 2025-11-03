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
  final Map<String, Map<String, dynamic>> _clasesMuestraActivas = {}; // Cambiado para almacenar más información
  final String _usuarioId = '1';
  List<Map<String, dynamic>> _integrantesFamilia = [];
  bool _loadingFamilia = true;

  @override
  void initState() {
    super.initState();
    _futureDeportivas = _loadActividadesDeportivas();
    _loadUserData();
  }

  // ... (mantener todos los métodos de _loadUserData hasta _getColorRol igual)

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
            if (usuario is String) {
              integrantes.add({
                'numero_usuario': usuario,
                'nombre': _obtenerNombreDeUsuario(usuario),
                'rol': _determinarRol(usuario),
              });
            } else if (usuario is Map) {
              final usuarioMap = Map<String, dynamic>.from(usuario);
              
              String nombreCompleto = _obtenerNombreCompletoDeUsuario(usuarioMap);
              
              integrantes.add({
                'numero_usuario': usuarioMap['numero_usuario']?.toString() ?? usuarioMap['id']?.toString() ?? 'N/A',
                'nombre': nombreCompleto,
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
        Uri.parse("https://clubfrance.org.mx/api/get_user_info.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final dataMap = Map<String, dynamic>.from(data);
          
          String nombreCompleto = _obtenerNombreCompletoDeUsuario(dataMap);
          
          setState(() {
            _integrantesFamilia = [{
              'numero_usuario': dataMap['numero_usuario']?.toString() ?? numeroUsuario,
              'nombre': nombreCompleto,
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
      _setIntegrantePorDefecto(numeroUsuario);
    }
  }

  void _setIntegrantePorDefecto(String numeroUsuario) {
    setState(() {
      _integrantesFamilia = [{
        'numero_usuario': numeroUsuario,
        'nombre': 'Usuario Principal',
        'rol': 'titular',
      }];
    });
  }

  String _obtenerNombreDeUsuario(String numeroUsuario) {
    final rol = _determinarRol(numeroUsuario);
    return _obtenerNombrePorRol(rol);
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
      case 'titular': return const Color.fromRGBO(25, 118, 210, 1);
      case 'conyuge': return Colors.purple;
      case 'hijo': return Colors.green;
      default: return Colors.grey;
    }
  }

  // Método para extraer días únicos de la actividad
  List<String> _extraerDiasDisponibles(SportActivity actividad) {
    final List<String> todosDias = [];
    
    if (actividad.tieneDias && actividad.diasFormateados.isNotEmpty) {
      final diasSeparados = actividad.diasFormateados.split(',').map((d) => d.trim()).toList();
      todosDias.addAll(diasSeparados);
    }
    
    return todosDias.where((dia) => dia.isNotEmpty).toSet().toList();
  }

  // Método para extraer horarios únicos de la actividad
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
    final actividades = await SportService.getActividadesDeportivas();
    
    _actividadesInfantiles = actividades.where((a) => a.isInfantil).toList();
    _actividadesAdultos = actividades.where((a) => a.isAdulto).toList();
    
    return actividades;
  }

  void _refreshData() {
    setState(() {
      _futureDeportivas = _loadActividadesDeportivas();
      _clasesMuestraActivas.clear();
    });
  }

  void _handleClaseMuestra(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    
    if (!_clasesMuestraActivas.containsKey(actividadId)) {
      _mostrarFormularioClaseMuestra(actividad);
    }
    // Eliminado el else - ya no hay segunda confirmación
  }

  void _mostrarFormularioClaseMuestra(SportActivity actividad) {
    String? integranteSeleccionado;
    String? diaSeleccionado;
    String? horarioSeleccionado;

    // Extraer días y horarios disponibles
    final diasDisponibles = _extraerDiasDisponibles(actividad);
    final horariosDisponibles = _extraerHorariosDisponibles(actividad);

    // Si solo hay un día/horario disponible, seleccionarlo automáticamente
    if (diasDisponibles.length == 1) {
      diaSeleccionado = diasDisponibles.first;
    }
    if (horariosDisponibles.length == 1) {
      horarioSeleccionado = horariosDisponibles.first;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Clase muestra - ${actividad.nombreActividad}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información de la actividad
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información de la actividad:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildActivityInfoRow(Icons.sports, 'Actividad:', actividad.nombreActividad),
                          _buildActivityInfoRow(Icons.person, 'Profesor:', actividad.nombreProfesor),
                          _buildActivityInfoRow(Icons.place, 'Ubicación:', actividad.lugar),
                          if (actividad.tieneDias)
                            _buildActivityInfoRow(Icons.calendar_today, 'Días:', actividad.diasFormateados),
                          if (actividad.horarios.isNotEmpty)
                            _buildActivityInfoRow(Icons.access_time, 'Horarios:', actividad.horarios.join('\n')),
                        ],
                      ),
                    ),
                  ),

                  // Selector de integrante
                  if (_loadingFamilia)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Cargando integrantes...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else if (_integrantesFamilia.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No se encontraron integrantes de la membresía',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 200,
                        maxWidth: 400,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona integrante de la membresía',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        initialValue: integranteSeleccionado,
                        items: _integrantesFamilia.map<DropdownMenuItem<String>>((integrante) {
                          final numeroUsuario = integrante['numero_usuario'] as String;
                          final nombre = integrante['nombre'] as String;
                          final rol = integrante['rol'] as String;
                          final rolDisplay = _getRolDisplay(rol);
                          final colorRol = _getColorRol(rol);
                          
                          return DropdownMenuItem<String>(
                            value: numeroUsuario,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre.isNotEmpty ? nombre : 'Nombre no disponible',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$numeroUsuario • $rolDisplay',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => integranteSeleccionado = value);
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Selector de día (solo si hay días disponibles)
                  if (diasDisponibles.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 200,
                        maxWidth: 400,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un día',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        initialValue: diaSeleccionado,
                        items: diasDisponibles.map<DropdownMenuItem<String>>((dia) {
                          return DropdownMenuItem<String>(
                            value: dia,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Text(
                                    dia,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => diaSeleccionado = value);
                        },
                      ),
                    ),

                  if (diasDisponibles.isNotEmpty) const SizedBox(height: 16),

                  // Selector de horario (solo si hay horarios disponibles)
                  if (horariosDisponibles.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 200,
                        maxWidth: 400,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un horario',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        initialValue: horarioSeleccionado,
                        items: horariosDisponibles.map<DropdownMenuItem<String>>((horario) {
                          return DropdownMenuItem<String>(
                            value: horario,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Text(
                                    horario,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => horarioSeleccionado = value);
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
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
                child: const Text('Confirmar clase muestra'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildActivityInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  void _asignarClaseMuestra({
    required SportActivity actividad,
    required String integrante,
    required String? diaSeleccionado,
    required String? horarioSeleccionado,
  }) {
    final actividadId = actividad.id.toString();
    
    // Almacenar toda la información de la clase muestra
    setState(() {
      _clasesMuestraActivas[actividadId] = {
        'integrante': integrante,
        'dia': diaSeleccionado,
        'horario': horarioSeleccionado,
        'fechaAsignacion': DateTime.now(),
      };
    });

    final integranteData = _integrantesFamilia.firstWhere(
      (i) => i['numero_usuario'] == integrante,
      orElse: () => {'nombre': integrante, 'rol': 'miembro'}
    );

    // Construir mensaje con la información completa
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
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // Eliminado el método _confirmarClaseMuestra - ya no es necesario

  void _cancelarClaseMuestra(SportActivity actividad) async {
    final actividadId = actividad.id.toString();
    
    // Mostrar diálogo de confirmación antes de cancelar
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

    final resultado = await ReservationService.cancelarReserva(
      actividadId: actividadId,
      usuarioId: _usuarioId,
    );
    
    if (!mounted) return;
    
    if (resultado['success']) {
      setState(() {
        _clasesMuestraActivas.remove(actividadId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? "Clase muestra cancelada para ${actividad.nombreActividad}"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? "Error al cancelar la clase muestra"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Actividades Deportivas",
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          return _buildContent();
        },
      ),
    );
  }

  // ... (mantener todos los métodos de build restantes)

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
                  color: _getColorWithOpacity(Colors.black, 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const TabBar(
              labelColor: Color.fromRGBO(13, 71, 161, 1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color.fromRGBO(13, 71, 161, 1),
              labelStyle: TextStyle(
                fontFamily: 'Montserrat',
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
                      fontFamily: 'Montserrat',
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
                      fontFamily: 'Montserrat',
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
                  color: _getColorWithOpacity(Colors.green, 0.1),
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
                            fontFamily: 'Montserrat',
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
                      ? Colors.grey // Cambiado a gris cuando ya está programada
                      : const Color.fromRGBO(13, 71, 161, 1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                icon: Icon(
                  tieneClaseMuestra ? Icons.check_circle : Icons.school,
                  size: 20,
                ),
                label: Text(
                  tieneClaseMuestra ? "CLASE MUESTRA PROGRAMADA" : "SOLICITAR CLASE MUESTRA", // Texto cambiado
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
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
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (actividad.horarios.isNotEmpty)
                  ...actividad.horarios.map((horario) => Text(
                    horario,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  )),
                if (!actividad.tieneDias && actividad.horarios.isEmpty)
                  const Text(
                    'Horario por confirmar',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
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
            fontFamily: 'Montserrat',
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
                  fontFamily: 'Montserrat',
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
          fontFamily: 'Montserrat',
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
                fontFamily: 'Montserrat',
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
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: _getMaterialColor(Colors.orange, 800),
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
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer, size: 64, color: _getMaterialColor(Colors.grey, 300)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "Error al cargar actividades",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text(
              "Reintentar",
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorWithOpacity(Color color, double opacity) {
    return Color.alphaBlend(color.withAlpha((opacity * 255).round()), Colors.transparent);
  }

  Color _getMaterialColor(MaterialColor color, int shade) {
    switch (shade) {
      case 50: return color.shade50;
      case 100: return color.shade100;
      case 200: return color.shade200;
      case 300: return color.shade300;
      case 400: return color.shade400;
      case 500: return color.shade500;
      case 600: return color.shade600;
      case 700: return color.shade700;
      case 800: return color.shade800;
      case 900: return color.shade900;
      default: return color;
    }
  }
}