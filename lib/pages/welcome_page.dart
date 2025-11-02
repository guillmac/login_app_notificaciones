import 'package:flutter/material.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  bool _showOptions = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _shineController;
  late Animation<double> _shineAnimation;

  late AnimationController _logoController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Fade + Slide botones
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(_controller);

    // Shine animado botones
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shineAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _shineController, curve: Curves.linear));

    // Logo animación Fade + Zoom
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_logoController);
    _logoScaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoController.forward();
  }

  void _showButtons() {
    setState(() => _showOptions = true);
    _controller.forward();
  }

  void _navigateToRegistration() {
    // Navegar a la página de registro (a implementar)
  }

  @override
  void dispose() {
    _controller.dispose();
    _shineController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Widget _shineButton({
    required String text,
    required Gradient gradient,
    required VoidCallback? onPressed,
    Color textColor = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withAlpha(128),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shineAnimation,
                    builder: (context, child) {
                      return FractionalTranslation(
                        translation: Offset(_shineAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color.alphaBlend(
                                Colors.white.withAlpha(25), Colors.transparent),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/1.jpg",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1a1a1a),
                        Color(0xFF2d2d2d),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFadeAnimation.value,
                  child: Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                "assets/images/logoblanco.png",
                width: 160,
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 160,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'CLUB FRANCE',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_showOptions)
                _shineButton(
                  text: "Comenzar",
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                  ),
                  textColor: Colors.black,
                  onPressed: _showButtons,
                )
              else
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _shineButton(
                          text: "Únete",
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                          ),
                          textColor: Colors.black,
                          onPressed: _navigateToRegistration,
                        ),
                        _shineButton(
                          text: "Soy usuario(a)",
                          gradient: const LinearGradient(
                            colors: [Colors.black87, Colors.black],
                          ),
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 50),
            ],
          ),
        ],
      ),
    );
  }
}
