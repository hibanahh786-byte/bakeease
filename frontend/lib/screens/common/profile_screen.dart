import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import 'package:provider/provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _apiService.get('users/me/');
      setState(() {
        _profileData = response.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile.')));
    }
  }

  Future<void> _editBakerAddressDialog() async {
    final bp = _profileData?['baker_profile'];
    if (bp == null) return;
    final cityCtrl = TextEditingController(text: bp['city'] ?? '');
    final addressCtrl = TextEditingController(text: bp['address'] ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Bakery Location'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: cityCtrl, decoration: InputDecoration(labelText: 'City')),
                    TextField(controller: addressCtrl, decoration: InputDecoration(labelText: 'Full Address'), maxLines: 2),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    try {
                      await _apiService.patch('users/profile/baker/', {
                        'city': cityCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                      });
                      Navigator.pop(ctx);
                      _fetchProfile();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location updated successfully')));
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update location.')));
                    }
                  },
                  child: isSaving ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _editAddressDialog() async {
    final cp = _profileData?['customer_profile'];
    if (cp == null) return;
    final houseCtrl = TextEditingController(text: cp['house_name'] ?? '');
    final streetCtrl = TextEditingController(text: cp['street'] ?? '');
    final cityCtrl = TextEditingController(text: cp['city'] ?? '');
    final stateCtrl = TextEditingController(text: cp['state'] ?? '');
    final pinCtrl = TextEditingController(text: cp['pincode'] ?? '');
    final landCtrl = TextEditingController(text: cp['landmarks'] ?? '');

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Delivery Address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: houseCtrl, decoration: InputDecoration(labelText: 'House Name/Flat No.')),
                    TextField(controller: streetCtrl, decoration: InputDecoration(labelText: 'Street/Area')),
                    TextField(controller: cityCtrl, decoration: InputDecoration(labelText: 'City')),
                    TextField(controller: stateCtrl, decoration: InputDecoration(labelText: 'State')),
                    TextField(controller: pinCtrl, decoration: InputDecoration(labelText: 'Pincode')),
                    TextField(controller: landCtrl, decoration: InputDecoration(labelText: 'Nearby Landmarks')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    try {
                      final combinedAddress = "${houseCtrl.text.trim()}, ${streetCtrl.text.trim()}, ${cityCtrl.text.trim()}, ${stateCtrl.text.trim()} - ${pinCtrl.text.trim()} (Landmark: ${landCtrl.text.trim()})".replaceAll(RegExp(r'^[, -]+|[, -]+$'), '');
                      await _apiService.patch('users/profile/customer/', {
                        'house_name': houseCtrl.text.trim(),
                        'street': streetCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'state': stateCtrl.text.trim(),
                        'pincode': pinCtrl.text.trim(),
                        'landmarks': landCtrl.text.trim(),
                        'address': combinedAddress,
                      });
                      Navigator.pop(ctx);
                      _fetchProfile();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Address updated successfully')));
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update address.')));
                    }
                  },
                  child: isSaving ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profileData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Failed to load profile data. Please try again.')),
      );
    }

    final role = _profileData!['role'];
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.brown[200],
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Divider(),
                    ListTile(title: Text('Username'), subtitle: Text(_profileData!['username'])),
                    ListTile(title: Text('Email'), subtitle: Text(_profileData!['email'])),
                    ListTile(title: Text('Role'), subtitle: Text(_profileData!['role'])),
                  ],
                ),
              ),
            ),
            if (role == 'BAKER' && _profileData!['baker_profile'] != null)
              Card(
                margin: EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Baker Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                           IconButton(
                             icon: Icon(Icons.edit, color: Colors.brown),
                             onPressed: _editBakerAddressDialog,
                             tooltip: 'Edit Location',
                           ),
                         ],
                       ),
                       Divider(),
                       ListTile(title: Text('City'), subtitle: Text(_profileData!['baker_profile']['city'] ?? 'Not provided')),
                       ListTile(title: Text('Address'), subtitle: Text(_profileData!['baker_profile']['address'] ?? 'Not provided')),
                       ListTile(title: Text('FSSAI Number'), subtitle: Text('${_profileData!['baker_profile']['fssai_number']}')),
                       ListTile(title: Text('Status'), subtitle: Text(_profileData!['baker_profile']['is_approved'] ? 'Approved' : 'Pending Approval')),
                    ],
                  ),
                ),
              ),
              
            if (role == 'CUSTOMER' && _profileData!['customer_profile'] != null)
              Card(
                margin: EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                           IconButton(
                             icon: Icon(Icons.edit, color: Colors.brown),
                             onPressed: _editAddressDialog,
                             tooltip: 'Edit Address',
                           ),
                         ],
                       ),
                       Divider(),
                       ListTile(
                         title: Text('Address'), 
                         subtitle: Text([
                           if (_profileData!['customer_profile']['house_name']?.isNotEmpty ?? false) _profileData!['customer_profile']['house_name'],
                           if (_profileData!['customer_profile']['street']?.isNotEmpty ?? false) _profileData!['customer_profile']['street'],
                           if (_profileData!['customer_profile']['city']?.isNotEmpty ?? false) _profileData!['customer_profile']['city'],
                           if (_profileData!['customer_profile']['state']?.isNotEmpty ?? false) _profileData!['customer_profile']['state'],
                           if (_profileData!['customer_profile']['pincode']?.isNotEmpty ?? false) _profileData!['customer_profile']['pincode'],
                           if (_profileData!['customer_profile']['landmarks']?.isNotEmpty ?? false) 'Landmark: ${_profileData!['customer_profile']['landmarks']}'
                         ].join(', ').isNotEmpty ? [
                           if (_profileData!['customer_profile']['house_name']?.isNotEmpty ?? false) _profileData!['customer_profile']['house_name'],
                           if (_profileData!['customer_profile']['street']?.isNotEmpty ?? false) _profileData!['customer_profile']['street'],
                           if (_profileData!['customer_profile']['city']?.isNotEmpty ?? false) _profileData!['customer_profile']['city'],
                           if (_profileData!['customer_profile']['state']?.isNotEmpty ?? false) _profileData!['customer_profile']['state'],
                           if (_profileData!['customer_profile']['pincode']?.isNotEmpty ?? false) _profileData!['customer_profile']['pincode'],
                           if (_profileData!['customer_profile']['landmarks']?.isNotEmpty ?? false) 'Landmark: ${_profileData!['customer_profile']['landmarks']}'
                         ].join(', ') : (_profileData!['customer_profile']['address'] ?? 'Not provided')),
                       ),
                       ListTile(title: Text('Contact Number'), subtitle: Text(_profileData!['customer_profile']['contact_number'] ?? 'Not provided')),
                    ]
                  )
                )
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                    content: const Text('Are you sure you want to permanently delete your account? All your order history and profile details will be lost. This cannot be undone.'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true), 
                        child: const Text('Delete')
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    setState(() => _isLoading = true);
                    await _apiService.delete('users/me/');
                    if (!mounted) return;
                    await Provider.of<AuthProvider>(context, listen: false).logout();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete account.')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
