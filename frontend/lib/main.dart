import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_provider.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const BakeEaseApp(),
    ),
  );
}

class BakeEaseApp extends StatelessWidget {
  const BakeEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return MaterialApp(
      title: 'BakeEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF8F5), // Soft creamy white
        primaryColor: const Color(0xFFE63946), // Raspberry Red
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFE63946),
          secondary: Color(0xFFF3E5AB), // Buttercream Yellow
          surface: Colors.white, 
          background: Color(0xFFFFF8F5),
          onPrimary: Colors.white,
          onSurface: Color(0xFF4A3022), // Chocolate Brown
        ),
        textTheme: GoogleFonts.quicksandTextTheme(textTheme).apply(
          bodyColor: const Color(0xFF4A3022),
          displayColor: const Color(0xFF4A3022),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Color(0xFF4A3022)),
          titleTextStyle: GoogleFonts.playfairDisplay(
            color: const Color(0xFF4A3022),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE63946), // Raspberry Red button
            foregroundColor: Colors.white, // White text inside button
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFE63946),
          unselectedItemColor: Colors.black38,
          elevation: 10,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => LoginScreen(),
      },
      home: LoginScreen(),
    );
  }
}
