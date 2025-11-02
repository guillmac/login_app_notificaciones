 import 'package:flutter/material.dart';
import '../models/sport_activity.dart';
import '../services/sport_service.dart';
import '../services/reservation_service.dart';

class SportsActivitiesPage extends StatefulWidget {
  const SportsActivitiesPage({super.key});

  @override
  State<SportsActivitiesPage> createState() => _SportsActivitiesPageState();
}

class _SportsActivitiesPageState extends State<SportsActivitiesPage> {
  late Future<List<SportActivity>> _futureDeportivas;
  List<SportActivity> _actividadesInfantiles = [];
  List<SportActivity> _actividadesAdultos = [];
  final Map<String, int?> _reservasActivas = {};
  final String _usuarioId = '1';

  @override
  void initState() {
    super.initState();
    _futureDeportivas = _loadActividadesDeportivas();
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
      _reservasActivas.clear();
    });
  }

  void _handleReserva(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    
    if (_reservasActivas[actividadId] == null) {
      _mostrarSeleccionLugares(actividad);
    } else {
      _procesarPago(actividad);
    }
  }

  void _mostrarSeleccionLugares(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              "Seleccionar Lugar",
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _buildSelectorLugares(actividad, setDialogState, context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
              ElevatedButton(
                onPressed: _reservasActivas[actividadId] != null 
                    ? () {
                        Navigator.pop(context);
                        _procesarPago(actividad);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(13, 71, 161, 1),
                ),
                child: const Text(
                  "Continuar al Pago",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectorLugares(SportActivity actividad, StateSetter setDialogState, BuildContext dialogContext) {
    final actividadId = actividad.id.toString();
    final lugarSeleccionado = _reservasActivas[actividadId];
    
    return FutureBuilder<List<int>>(
      future: ReservationService.getLugaresOcupados(actividadId),
      builder: (context, snapshot) {
        final lugaresOcupados = snapshot.data ?? [];
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selecciona un lugar disponible (${actividad.nombreActividad})",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Lugares Disponibles:",
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: 10,
              itemBuilder: (context, index) {
                final numeroLugar = index + 1;
                final estaSeleccionado = lugarSeleccionado == numeroLugar;
                final estaOcupado = lugaresOcupados.contains(numeroLugar);

                return GestureDetector(
                  onTap: !estaOcupado 
                      ? () => _reservarLugar(
                            actividadId: actividadId,
                            numeroLugar: numeroLugar,
                            setDialogState: setDialogState,
                            dialogContext: dialogContext,
                          )
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: estaOcupado 
                          ? Colors.grey[300]
                          : estaSeleccionado
                              ? const Color.fromRGBO(13, 71, 161, 1)
                              : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: estaSeleccionado 
                            ? const Color.fromRGBO(13, 71, 161, 1)
                            : Colors.grey[300]!,
                        width: estaSeleccionado ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$numeroLugar',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: estaOcupado 
                                  ? Colors.grey[600]
                                  : estaSeleccionado
                                      ? Colors.white
                                      : const Color.fromRGBO(13, 71, 161, 1),
                            ),
                          ),
                          if (estaOcupado)
                            const Icon(
                              Icons.block,
                              size: 12,
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (lugarSeleccionado != null)
              Text(
                "Lugar seleccionado: $lugarSeleccionado",
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(13, 71, 161, 1),
                ),
              ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _reservarLugar({
    required String actividadId,
    required int numeroLugar,
    required StateSetter setDialogState,
    required BuildContext dialogContext,
  }) async {
    setDialogState(() {
      _reservasActivas[actividadId] = numeroLugar;
    });
    
    final resultado = await ReservationService.reservarLugar(
      actividadId: actividadId,
      numeroLugar: numeroLugar,
      usuarioId: _usuarioId,
    );
    
    if (!resultado['success']) {
      setDialogState(() {
        _reservasActivas.remove(actividadId);
      });
      
      // Use the dialog context for showing snackbar in the dialog
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Error al reservar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Lugar reservado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _procesarPago(SportActivity actividad) {
    final actividadId = actividad.id.toString();
    final lugarSeleccionado = _reservasActivas[actividadId];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Confirmar Reserva y Pago",
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
        ),
        content: Text(
          "¿Desea proceder con el pago para:\n\n"
          "${actividad.nombreActividad}\n"
          "Lugar: $lugarSeleccionado",
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Use the widget's context for the main page snackbar
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Redirigiendo al pago: ${actividad.nombreActividad} - Lugar $lugarSeleccionado",
                      style: const TextStyle(fontFamily: 'Montserrat'),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Limpiar la reserva después del pago
                setState(() {
                  _reservasActivas.remove(actividadId);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(13, 71, 161, 1),
            ),
            child: const Text(
              "Pagar Ahora",
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelarReserva(SportActivity actividad) async {
    final actividadId = actividad.id.toString();
    
    final resultado = await ReservationService.cancelarReserva(
      actividadId: actividadId,
      usuarioId: _usuarioId,
    );
    
    if (!mounted) return;
    
    if (resultado['success']) {
      setState(() {
        _reservasActivas.remove(actividadId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? "Reserva cancelada para ${actividad.nombreActividad}"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? "Error al cancelar la reserva"),
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

  // ... (rest of the methods remain the same - _buildContent, _buildListaActividades, etc.)

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

  // ... (rest of the UI builder methods remain unchanged)
  Widget _buildTarjetaActividad(SportActivity actividad, Color color) {
    final actividadId = actividad.id.toString();
    final tieneReserva = _reservasActivas.containsKey(actividadId);
    final lugarSeleccionado = _reservasActivas[actividadId];

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
            
            if (tieneReserva)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _getColorWithOpacity(Colors.green, 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Lugar reservado: $lugarSeleccionado",
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                      onPressed: () => _cancelarReserva(actividad),
                      tooltip: "Cancelar reserva",
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () => _handleReserva(actividad),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tieneReserva 
                      ? Colors.green
                      : const Color.fromRGBO(13, 71, 161, 1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                icon: Icon(
                  tieneReserva ? Icons.payment : Icons.assignment_turned_in,
                  size: 20,
                ),
                label: Text(
                  tieneReserva ? "PAGAR RESERVA" : "RESERVAR ACTIVIDAD",
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