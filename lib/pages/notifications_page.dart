import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final notifications = await NotificationService.getStoredNotifications();
    
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllNotificationsAsRead();
    await _loadNotifications();
    
    if (!mounted) return;
    _showSnackBar(
      "Todas las notificaciones marcadas como leídas",
      Colors.green,
    );
  }

  Future<void> _clearAllNotifications() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Eliminar notificaciones",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "¿Estás seguro de que quieres eliminar todas las notificaciones?",
            style: TextStyle(
              fontFamily: 'Montserrat',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Cancelar",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Eliminar",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await NotificationService.clearAllStoredNotifications();
      await _loadNotifications();
      
      if (!mounted) return;
      _showSnackBar(
        "Todas las notificaciones han sido eliminadas",
        Colors.green,
      );
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final title = notification['title'] ?? 'Sin título';
    final body = notification['body'] ?? '';
    final timestamp = DateTime.parse(notification['timestamp']);
    final id = notification['id'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: isRead ? Colors.white : Colors.blue.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Título y estado
            Row(
              children: [
                // Ícono
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey.shade300 : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: isRead ? Colors.grey : Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: isRead ? Colors.grey.shade700 : Colors.black,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Badge de no leído
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Cuerpo del mensaje - MÁXIMA FLEXIBILIDAD
            Text(
              body,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
              maxLines: 6, // ✅ Hasta 6 líneas para texto largo
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 10),
            
            // Fecha
            Row(
              children: [
                Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                
                // Botón para marcar como leída si no lo está
                if (!isRead)
                  TextButton(
                    onPressed: () async {
                      await NotificationService.markNotificationAsRead(id);
                      if (mounted) {
                        await _loadNotifications();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Marcar como leída',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Ahora mismo';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} d';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notificaciones",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Marcar todas como leídas',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllNotifications,
              tooltip: 'Eliminar todas las notificaciones',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No hay notificaciones",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Las notificaciones push aparecerán aquí",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(_notifications[index]);
                    },
                  ),
                ),
    );
  }
}