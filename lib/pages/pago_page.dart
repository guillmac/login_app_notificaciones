import 'package:flutter/material.dart';

class PagoPage extends StatelessWidget {
  final String actividad;

  const PagoPage({super.key, required this.actividad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pagar $actividad"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Text(
          "Formulario de pago para $actividad",
          style: const TextStyle(fontSize: 18, fontFamily: "Montserrat"),
        ),
      ),
    );
  }
}
