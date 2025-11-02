import 'package:flutter/material.dart';

class ReservaPage extends StatelessWidget {
  final String actividad;

  const ReservaPage({super.key, required this.actividad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reservar $actividad"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Text(
          "Formulario de reserva para $actividad",
          style: const TextStyle(fontSize: 18, fontFamily: "Montserrat"),
        ),
      ),
    );
  }
}
