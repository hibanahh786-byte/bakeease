import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import 'package:provider/provider.dart';
import '../baker/dashboard_screen.dart';

class BakerOnboardingScreen extends StatefulWidget {
  @override
  _BakerOnboardingScreenState createState() => _BakerOnboardingScreenState();
}

class _BakerOnboardingScreenState extends State<BakerOnboardingScreen> {
  final _fssaiNumberController = TextEditingController();
  File? _fssaiDocument;
  bool _isLoading = false;

  Future<void> _pickDocument() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _fssaiDocument = File(pickedFile.path);
      });
    }
  }

  void _submitDetails() async {
    if (_fssaiNumberController.text.isEmpty || _fssaiDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please provide all details (FSSAI and Document).')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      FormData formData = FormData.fromMap({
        'fssai_number': _fssaiNumberController.text,
        'fssai_document': await MultipartFile.fromFile(_fssaiDocument!.path, filename: 'fssai_doc.jpg'),
      });

      await ApiService().patch('users/profile/baker/', formData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Details submitted successfully, awaiting approval!')));
      
      // Navigate to the dashboard
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BakerDashboardScreen()));
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: ${e.message}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacementNamed(context, '/'); // Assumes '/' is the login/initial route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Baker Onboarding'),
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Welcome Baker! Please submit your registration details.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            TextField(controller: _fssaiNumberController, decoration: InputDecoration(labelText: 'FSSAI License Number')),
            SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(onPressed: _pickDocument, child: Text('Upload FSSAI Doc')),
                SizedBox(width: 10),
                Expanded(child: Text(_fssaiDocument != null ? 'File selected' : 'No file selected')),
              ],
            ),

            Spacer(),
            _isLoading 
                ? CircularProgressIndicator() 
                : ElevatedButton(
                    onPressed: _submitDetails, 
                    child: Text('Submit Application'),
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                  ),
          ],
        ),
      ),
    );
  }
}
