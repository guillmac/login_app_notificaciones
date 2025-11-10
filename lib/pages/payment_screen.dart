import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentScreen({super.key, required this.paymentData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentCompleted = false;

  String _generateHtmlForm() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Procesando Pago - Club France</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 500px;
            width: 100%;
        }
        .loading {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 20px;
        }
        .spinner {
            width: 50px;
            height: 50px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="loading">
            <h2>🔄 Procesando Pago</h2>
            <div class="spinner"></div>
            <p>Estamos redirigiéndote a la pasarela de pago segura...</p>
            <p style="font-size: 12px; color: #666;">Por favor no cierre esta ventana</p>
        </div>
    </div>
    
    <form id="paymentForm" action="${widget.paymentData['payment_url']}" method="post">
        <input type="hidden" name="importe" value="${widget.paymentData['importe']}"/>
        <input type="hidden" name="referencia" value="${widget.paymentData['referencia']}"/>
        <input type="hidden" name="urlretorno" value="${widget.paymentData['urlretorno']}"/>
        <input type="hidden" name="idexpress" value="${widget.paymentData['idexpress']}"/>
        <input type="hidden" name="financiamiento" value="0"/>
        <input type="hidden" name="plazos" value=""/>
        <input type="hidden" name="mediospago" value="100000"/>
        <input type="hidden" name="signature" value="${widget.paymentData['signature']}"/>
    </form>
    
    <script>
        // Auto-submit form after short delay
        setTimeout(function() {
            document.getElementById('paymentForm').submit();
        }, 1500);
    </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
        },
        onUrlChange: (UrlChange change) {
          _handleUrlChange(change.url ?? '');
        },
        onWebResourceError: (WebResourceError error) {
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog('Error de conexión: ${error.description}');
        },
      ))
      ..loadHtmlString(_generateHtmlForm());
  }

  void _handleUrlChange(String url) {
    print('URL cambiada: $url');
    
    // Verificar si es la URL de retorno del callback
    if (url.contains('payment_callback.php')) {
      setState(() {
        _paymentCompleted = true;
      });
      
      // Esperar un momento y luego cerrar con éxito
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pop({'success': true, 'message': 'Pago procesado'});
        }
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error en el pago'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Procesar Pago'),
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _showExitConfirmation,
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && !_paymentCompleted)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Cargando pasarela de pago...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (_paymentCompleted)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Procesando pago...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Por favor espere',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar pago?'),
        content: const Text('Si sales ahora, el proceso de pago se cancelará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop({'success': false, 'cancelled': true});
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}