import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/auth_background.dart';
import '../../services/auth_provider.dart';
import 'register_screen.dart';
import 'baker_onboarding.dart';
import '../customer/home_screen.dart'; 
import '../baker/dashboard_screen.dart'; 
import '../admin/dashboard_screen.dart';
import '../delivery/delivery_dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _usernameController.text.trim().toLowerCase(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (success) {
      if (auth.userRole == 'BAKER') {
        if (auth.needsOnboarding) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BakerOnboardingScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BakerDashboardScreen()));
        }
      } else if (auth.userRole == 'ADMIN') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboardScreen()));
      } else if (auth.userRole == 'DELIVERY_PERSON') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerHomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
    }
  }

  void _showInputsPage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _showLandingPage() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackgroundLayout(
        child: Stack(
          children: [
            // 1. Floating Decorative Icons (Mockup style)
            Positioned(
              top: 50,
              left: 40,
              child: Icon(Icons.favorite, color: const Color(0xFFE63946).withOpacity(0.15), size: 28),
            ),
            Positioned(
              top: 140,
              right: 50,
              child: Icon(Icons.auto_awesome, color: const Color(0xFFE63946).withOpacity(0.2), size: 24),
            ),
            Positioned(
              bottom: 120,
              left: 30,
              child: Icon(Icons.cookie_outlined, color: const Color(0xFF4A3022).withOpacity(0.08), size: 64),
            ),
            Positioned(
              bottom: 110,
              right: 35,
              child: Icon(Icons.rice_bowl_outlined, color: const Color(0xFF4A3022).withOpacity(0.06), size: 60), // Mock Whisk shape
            ),
            Positioned(
              bottom: 240,
              right: 60,
              child: Icon(Icons.favorite, color: const Color(0xFFE63946).withOpacity(0.15), size: 20),
            ),

            // 2. PageView Content
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Require button click for fluid animation
              children: [
                // PAGE 0: Welcome Landing (mockup style)
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Circular branding logo
                        Image.asset(
                          'assets/images/logo.png',
                          height: 250,
                        ),
                        const SizedBox(height: 24),
                        // Welcome text
                        Text(
                          'Welcome to',
                          style: GoogleFonts.quicksand(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A3022).withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Bubbly Script Text Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFE63946), Color(0xFFE63946)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                'BakeEase',
                                style: GoogleFonts.satisfy(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Transform.translate(
                              offset: const Offset(0, -8),
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFE63946), Color(0xFFE63946)],
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.favorite,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        Text(
                          'Bake your happiness with ease 🍰',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A3022).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Center 3D Cake Image
                        Container(
                          height: 240,
                          child: Image.asset(
                            'assets/images/login_cake.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 45),
                        // Pill-shaped gradient Sign In button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE63946), Color(0xFFE63946)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE63946).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _showInputsPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign in',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // horizontal divider "or"
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: const Color(0xFF4A3022).withOpacity(0.1))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.quicksand(
                                    color: const Color(0xFF4A3022).withOpacity(0.4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: const Color(0xFF4A3022).withOpacity(0.1))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Don't have account span
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                color: const Color(0xFF4A3022).withOpacity(0.65),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RegisterScreen()),
                              ),
                              child: Text(
                                'Sign up',
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE63946),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // PAGE 1: Sign In Inputs
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back navigation button
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A3022), size: 26),
                          onPressed: _showLandingPage,
                        ),
                        const SizedBox(height: 10),
                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 180,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Form Card container
                        Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE63946).withOpacity(0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4A3022),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Username input
                                TextField(
                                  controller: _usernameController,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    hintText: 'Username',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE63946)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Password input
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE63946)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Gradient action button
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading 
                                    ? const Center(child: CircularProgressIndicator()) 
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE63946), Color(0xFFE63946)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Sign in',
                                                style: GoogleFonts.quicksand(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 24),
                                const Divider(color: Color(0xFFEEEEEE)),
                                const SizedBox(height: 16),
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Don\'t have an account? ',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => RegisterScreen()),
                                        ),
                                        child: Text(
                                          'Sign up',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFE63946),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}


