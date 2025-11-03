import 'package:flutter/material.dart';
import '../models/sport_activity.dart';
import '../services/reservation_service.dart';

class SelectorLugaresDialog extends StatefulWidget {
  final SportActivity actividad;
  final String usuarioId;

  const SelectorLugaresDialog({
    super.key,
    required this.actividad,
    required this.usuarioId,
  });

  @override
  State<SelectorLugaresDialog> createState() => _SelectorLugaresDialogState();
}

class _SelectorLugaresDialogState extends State<SelectorLugaresDialog> {
  int? _lugarSeleccionado;
  late Future<List<int>> _lugaresOcupadosFuture;

  @override
  void initState() {
    super.initState();
    _lugaresOcupadosFuture = _cargarLugaresOcupados();
  }

  Future<List<int>> _cargarLugaresOcupados() async {
    return await ReservationService.getLugaresOcupados(
      widget.actividad.id.toString(),
    );
  }

  Future<void> _reservarLugar(int numeroLugar) async {
    final resultado = await ReservationService.reservarLugar(
      actividadId: widget.actividad.id.toString(),
      numeroLugar: numeroLugar,
      usuarioId: widget.usuarioId,
    );

    if (!mounted) return;

    if (resultado['success']) {
      setState(() {
        _lugarSeleccionado = numeroLugar;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? 'Lugar reservado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? 'Error al reservar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Seleccionar Lugar",
        style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<int>>(
          future: _lugaresOcupadosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final lugaresOcupados = snapshot.data ?? [];
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selecciona un lugar disponible (${widget.actividad.nombreActividad})",
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
                _buildGridLugares(lugaresOcupados),
                if (_lugarSeleccionado != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Lugar seleccionado: $_lugarSeleccionado",
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(13, 71, 161, 1),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
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
          onPressed: _lugarSeleccionado != null 
              ? () => Navigator.pop(context, _lugarSeleccionado)
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
  }

  Widget _buildGridLugares(List<int> lugaresOcupados) {
    return GridView.builder(
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
        final estaSeleccionado = _lugarSeleccionado == numeroLugar;
        final estaOcupado = lugaresOcupados.contains(numeroLugar);

        return GestureDetector(
          onTap: !estaOcupado 
              ? () => _reservarLugar(numeroLugar)
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
    );
  }
}