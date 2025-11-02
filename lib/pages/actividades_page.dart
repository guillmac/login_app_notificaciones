import 'package:flutter/material.dart';
import 'reserva_page.dart';
import 'pago_page.dart';

class ActividadesPage extends StatelessWidget {
  const ActividadesPage({super.key});

  final List<Map<String, dynamic>> deportivas = const [
    {"nombre": "Fútbol", "color": Colors.green},
    {"nombre": "Tenis", "color": Colors.orange},
    {"nombre": "Natación", "color": Colors.blue},
  ];

  final List<Map<String, dynamic>> culturales = const [
    {"nombre": "Música", "color": Colors.purple},
    {"nombre": "Danza", "color": Colors.red},
    {"nombre": "Teatro", "color": Colors.teal},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Actividades"),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Slide de imágenes de actividades
            SizedBox(
              height: 200,
              child: PageView(
                controller: PageController(viewportFraction: 0.85),
                children: [
                  _slideImage("https://picsum.photos/400/200?image=10"),
                  _slideImage("https://picsum.photos/400/200?image=20"),
                  _slideImage("https://picsum.photos/400/200?image=30"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Actividades Deportivas
            _sectionTitle("Deportivas"),
            ...deportivas.map((act) => _activityCard(context, act)),
            const SizedBox(height: 20),
            // Actividades Culturales
            _sectionTitle("Culturales"),
            ...culturales.map((act) => _activityCard(context, act)),
          ],
        ),
      ),
    );
  }

  Widget _slideImage(String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _activityCard(BuildContext context, Map<String, dynamic> act) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              act["nombre"],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: act["color"],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservaPage(actividad: act["nombre"]),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Reservar"),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagoPage(actividad: act["nombre"]),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text("Pagar"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Horarios: Lunes a Viernes 8:00-20:00",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
