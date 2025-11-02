import 'package:flutter/material.dart';
import '../models/cultural_activity.dart';
import '../services/cultural_service.dart';

class CulturalActivitiesPage extends StatefulWidget {
  const CulturalActivitiesPage({super.key});

  @override
  State<CulturalActivitiesPage> createState() => _CulturalActivitiesPageState();
}

class _CulturalActivitiesPageState extends State<CulturalActivitiesPage> {
  late Future<List<CulturalActivity>> _futureCulturales;
  List<CulturalActivity> _actividadesInfantiles = [];
  List<CulturalActivity> _actividadesAdultos = [];

  @override
  void initState() {
    super.initState();
    _futureCulturales = _loadActividadesCulturales();
  }

  Future<List<CulturalActivity>> _loadActividadesCulturales() async {
    final actividades = await CulturalService.getActividadesCulturales();
    
    _actividadesInfantiles = actividades.where((a) => a.isInfantil).toList();
    _actividadesAdultos = actividades.where((a) => a.isAdulto).toList();
    
    return actividades;
  }

  void _refreshData() {
    setState(() {
      _futureCulturales = _loadActividadesCulturales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Actividades Culturales",
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
      body: FutureBuilder<List<CulturalActivity>>(
        future: _futureCulturales,
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
                  color: Colors.black.withValues(alpha: 0.1), // Fixed here
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
                _buildListaActividades(_actividadesInfantiles, Colors.purple),
                _buildListaActividades(_actividadesAdultos, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaActividades(List<CulturalActivity> actividades, Color color) {
    if (actividades.isEmpty) {
      return _buildEmptyState("No hay actividades culturales disponibles");
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadActividadesCulturales();
        setState(() {});
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

  Widget _buildTarjetaActividad(CulturalActivity actividad, Color color) {
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
                    color: color.withValues(alpha: 0.1), // Fixed here
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
            
            // Información básica
            _buildInfoRow(Icons.person, actividad.profesor),
            _buildInfoRow(Icons.place, actividad.lugar),
            if (actividad.celular.isNotEmpty && actividad.celular.toLowerCase() != 'n/a')
              _buildInfoRow(Icons.phone, actividad.celular),
            if (actividad.facebook.isNotEmpty && actividad.facebook.toLowerCase() != 'n/a')
              _buildInfoRow(Icons.facebook, actividad.facebook),
            
            // Días y Horarios
            _buildDiasYHorarios(actividad),
            
            // Grupos (si existen)
            if (actividad.grupos.isNotEmpty && actividad.grupos.length > 1) 
              _buildGrupos(actividad),
            
            // Avisos
            if (actividad.avisos.isNotEmpty && actividad.avisos.toLowerCase() != 'n/a') 
              _buildAvisos(actividad),
          ],
        ),
      ),
    );
  }

  Widget _buildDiasYHorarios(CulturalActivity actividad) {
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
                // Días - usa diasFormateados que usa dia1-dia7
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
                // Horarios
                if (actividad.tieneHorarios)
                  Text(
                    actividad.horariosFormateados,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                // Si no hay información de días ni horarios
                if (!actividad.tieneDias && !actividad.tieneHorarios)
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

  Widget _buildGrupos(CulturalActivity actividad) {
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
              backgroundColor: Colors.purple.withValues(alpha: 0.1), // Fixed here
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAvisos(CulturalActivity actividad) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1), // Fixed here
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
                    color: Colors.orange.withValues(alpha: 0.8), // Fixed here
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
          Icon(Icons.music_note, size: 64, color: Colors.grey.withValues(alpha: 0.3)), // Fixed here
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
            "Error al cargar actividades culturales",
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
}