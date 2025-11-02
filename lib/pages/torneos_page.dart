import 'package:flutter/material.dart';

class TorneosPage extends StatelessWidget {
  const TorneosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Torneos')),
      body: const Center(
        child: Text(
          'Información y resultados de torneos',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
