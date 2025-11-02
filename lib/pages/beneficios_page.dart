import 'package:flutter/material.dart';

class BeneficiosPage extends StatelessWidget {
  const BeneficiosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beneficios')),
      body: const Center(
        child: Text(
          'Aquí van Descuentos y convenios del Club para los usuarios.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
