import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/auth_background.dart';
import '../onboarding_screen.dart';
import 'baker_onboarding.dart';
import '../delivery/delivery_dashboard_screen.dart';
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _fssaiNumberController = TextEditingController();
  final _vehicleDetailsController = TextEditingController();
  File? _fssaiDocument;
  String _role = 'CUSTOMER';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _pickFssaiDocument() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _fssaiDocument = File(pickedFile.path));
    }
  }

  void _register() async {
    setState(() => _isLoading = true);
    try {
      FormData formData = FormData.fromMap({
        'username': _usernameController.text.trim().toLowerCase(),
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
        'role': _role,
        'contact_number': _contactController.text.trim(),
        if (_role == 'CUSTOMER') 'address': _addressController.text.trim(),
        if (_role == 'DELIVERY_PERSON') 'vehicle_details': _vehicleDetailsController.text.trim(),
        if (_role == 'BAKER') ...{
          'fssai_number': _fssaiNumberController.text.trim(),
          if (_fssaiDocument != null)
            'fssai_document': await MultipartFile.fromFile(_fssaiDocument!.path, filename: 'fssai_cert.jpg'),
        },
      });

      await ApiService().postPublic('users/register/', formData);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final loginSuccess = await auth.login(_usernameController.text.trim().toLowerCase(), _passwordController.text);
      if (loginSuccess) {
        if (auth.userRole == 'BAKER') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BakerOnboardingScreen()));
        } else if (auth.userRole == 'DELIVERY_PERSON') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration successful. Please login.')),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.response?.data}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackgroundLayout(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button & Logo Area
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A3022)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 180,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  
                  // Main Form Card
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: GoogleFonts.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A3022),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(_usernameController, 'Username', keyboardType: TextInputType.text),
                          const SizedBox(height: 12),
                          
                          _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          
                          _buildTextField(
                            _passwordController,
                            'Password',
                            obscure: _obscurePassword,
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
                          ),
                          const SizedBox(height: 12),
                          
                          // Role Dropdown mapped to the new flat style
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _role,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                items: <String>['CUSTOMER', 'BAKER', 'DELIVERY_PERSON'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value == 'DELIVERY_PERSON' ? 'DELIVERY PERSON' : value, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _role = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          _buildTextField(_contactController, 'Contact Number', keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                            
                          if (_role == 'CUSTOMER')
                            _buildTextField(_addressController, 'Address'),
                          
                          if (_role == 'DELIVERY_PERSON')
                            _buildTextField(_vehicleDetailsController, 'Vehicle Details (e.g., Honda Activa)'),
                          
                          if (_role == 'BAKER') ...[
                            _buildTextField(_fssaiNumberController, 'FSSAI License Number'),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickFssaiDocument,
                              icon: Icon(Icons.upload_file, color: Colors.grey.shade600),
                              label: Text(_fssaiDocument == null ? 'Upload FSSAI Certificate' : 'Certificate Uploaded', style: TextStyle(color: Colors.grey.shade800)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Sign Up Button
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE63946).withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _register,
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
                                          'Sign up',
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
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 16),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    'Sign in',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4A3022),
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
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: (hint == 'Username' || hint == 'Email') ? TextCapitalization.none : TextCapitalization.sentences,
      autocorrect: hint != 'Username' && hint != 'Email' && !obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        suffixIcon: suffixIcon,
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
    );
  }
}
