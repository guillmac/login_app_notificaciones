import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (!await launchUrl(launchUri)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Contacto",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de Contacto Principal
            _buildContactCard(
              icon: Icons.phone,
              title: "Teléfonos",
              children: [
                _buildContactItem(
                  "Conmutador",
                  "+1 (551) 1630700",
                  onTap: () => _makePhoneCall("+15511630700"),
                ),
        
              ],
            ),

            const SizedBox(height: 20),

            // Correos Electrónicos
            _buildContactCard(
              icon: Icons.email,
              title: "Correo Electrónico",
              children: [
                _buildContactItem(
                  "Información",
                  "recepcion@clubfrance.org.mx",
                  onTap: () => _sendEmail("recepcion@clubfrance.org.mx"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Horarios de Atención
            _buildContactCard(
              icon: Icons.access_time,
              title: "Horarios del Club",
              children: [
                _buildScheduleItem("Lunes a Viernes", "6:00 AM - 10:00 PM"),
                _buildScheduleItem("Sábados", "7:00 AM - 8:00 PM"),
                _buildScheduleItem("Domingos", "7:00 AM - 6:00 PM"),
                _buildScheduleItem("Días Festivos", "8:00 AM - 4:00 PM"),
              ],
            ),

            const SizedBox(height: 30),

            // Información Adicional
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 50), // grey[50]
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 300)), // grey[300]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.info, size: 40, color: Colors.blue),
                  const SizedBox(height: 12),
                  const Text(
                    "¿Necesitas ayuda inmediata?",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Nuestro equipo está disponible para asistirte en cualquier momento.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _makePhoneCall("+15551234567"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 80, 49, 218),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      "LLAMADA A PARAMEDICOS",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color.fromRGBO(13, 71, 161, 1)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(String label, String value, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: onTap != null ? const Color.fromRGBO(33, 150, 243, 1) : Colors.black87, // Colors.blue[700]
                    fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String day, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}