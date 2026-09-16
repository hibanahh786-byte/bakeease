import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  AddProductScreen({this.product});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _flavorsController = TextEditingController();
  final _sizesController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _discountPriceController = TextEditingController();
  bool _allowsCustomization = false;
  
  final List<String> _predefinedFlavors = [
    'Chocolate', 'Vanilla', 'Strawberry', 'Red Velvet', 'Butterscotch', 
    'Pineapple', 'Black Forest', 'Blueberry', 'Mango', 'Coffee'
  ];
  List<String> _selectedFlavors = [];
  
  List<String> _predefinedProductNames = [
    'Custom Cake', 'Black Forest Cake', 'Chocolate Truffle Cake', 
    'Red Velvet Cake', 'Butterscotch Cake', 'Pineapple Cake',
    'Strawberry Cake', 'Fruit Cake', 'Cheesecake', 'Brownies', 
    'Cupcakes (Set of 6)', 'Macarons (Box of 12)'
  ];
  String? _selectedProductName;
  
  File? _productImage;
  bool _isLoading = false;
  List<dynamic> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      String existingName = widget.product!['name'];
      if (!_predefinedProductNames.contains(existingName)) {
        _predefinedProductNames.add(existingName);
      }
      _selectedProductName = existingName;
      
      _descriptionController.text = widget.product!['description'];
      _priceController.text = widget.product!['base_price'].toString();
      _flavorsController.text = widget.product!['available_flavors'];
      _sizesController.text = widget.product!['available_sizes'];
      _prepTimeController.text = widget.product!['preparation_time_hours'].toString();
      _selectedCategoryId = widget.product!['category'];
      if (widget.product!['discount_price'] != null) {
        _discountPriceController.text = widget.product!['discount_price'].toString();
      }
      _allowsCustomization = widget.product!['allows_customization'] ?? false;
      
      if (widget.product!['available_flavors'] != null && widget.product!['available_flavors'].toString().isNotEmpty) {
        _selectedFlavors = widget.product!['available_flavors']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
            
        for (String f in _selectedFlavors) {
          if (!_predefinedFlavors.contains(f)) {
            _predefinedFlavors.add(f);
          }
        }
      }
    }
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiService().get('products/categories/');
      setState(() {
        _categories = response.data;
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _productImage = File(pickedFile.path));
    }
  }

  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic> data = {
        'name': _selectedProductName ?? '',
        'description': _descriptionController.text,
        'base_price': _priceController.text,
        'available_flavors': _selectedFlavors.join(', '),
        'available_sizes': _sizesController.text,
        'preparation_time_hours': _prepTimeController.text.isNotEmpty ? _prepTimeController.text : '24',
        'allows_customization': _allowsCustomization.toString(),
      };
      
      if (_discountPriceController.text.isNotEmpty) {
        data['discount_price'] = _discountPriceController.text;
      }
      
      if (_selectedCategoryId != null) {
        data['category'] = _selectedCategoryId;
      }
      
      if (_productImage != null) {
        data['image'] = await MultipartFile.fromFile(_productImage!.path, filename: 'product_image.jpg');
      }

      FormData formData = FormData.fromMap(data);

      if (widget.product == null) {
        await ApiService().post('products/items/', formData);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product added successfully!')));
      } else {
        await ApiService().patch('products/items/${widget.product!['id']}/', formData);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product updated successfully!')));
      }
      Navigator.pop(context, true); // Return true to signal a refresh
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save product: ${e.response?.data}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteProduct() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to permanently delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await ApiService().delete('products/items/${widget.product!['id']}/');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product deleted.')));
        Navigator.pop(context, true);
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete product.')));
      }
    }
  }

  void _showMultiSelectDialog() async {
    final List<String> tempSelected = List.from(_selectedFlavors);
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Flavors'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: _predefinedFlavors.map((flavor) {
                    return CheckboxListTile(
                      value: tempSelected.contains(flavor),
                      title: Text(flavor),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFFED3F47),
                      onChanged: (bool? checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            tempSelected.add(flavor);
                          } else {
                            tempSelected.remove(flavor);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('OK', style: TextStyle(color: Color(0xFFED3F47))),
                  onPressed: () {
                    setState(() {
                      _selectedFlavors = List.from(tempSelected);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add New Product' : 'Edit Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _productImage != null
                      ? Image.file(_productImage!, fit: BoxFit.cover)
                      : (widget.product != null && widget.product!['image'] != null)
                          ? Image.network(
                              widget.product!['image'].toString().startsWith('http') ? widget.product!['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                  : 'http://172.20.10.6:8000${widget.product!['image']}',
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                                Text('Tap to add product photo', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProductName,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                items: _predefinedProductNames.map<DropdownMenuItem<String>>((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProductName = val;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Please select a product name' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'] as int,
                    child: Text(cat['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                  });
                },
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Base Price (₹)', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: _showMultiSelectDialog,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Available Flavors',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _selectedFlavors.isEmpty ? 'Select Flavors' : _selectedFlavors.join(', '),
                    style: TextStyle(
                      color: _selectedFlavors.isEmpty ? Colors.grey[600] : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (_selectedFlavors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Please select at least one flavor',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _sizesController,
                decoration: InputDecoration(labelText: 'Sizes (comma separated)', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter at least one size' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _prepTimeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Preparation Time (Hours)', border: OutlineInputBorder(), hintText: '24'),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _discountPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Discount Price (₹) (Optional)', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Allows Customization', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Can customers request custom designs/messages?'),
                value: _allowsCustomization,
                activeColor: const Color(0xFFED3F47),
                onChanged: (bool value) {
                  setState(() {
                    _allowsCustomization = value;
                  });
                },
              ),
              SizedBox(height: 24),
              _isLoading 
                 ? Center(child: CircularProgressIndicator())
                 : Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Container(
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(
                             colors: [Color(0xFFF14966), Color(0xFFFF9E59)],
                             begin: Alignment.centerLeft,
                             end: Alignment.centerRight,
                           ),
                           borderRadius: BorderRadius.circular(30),
                           boxShadow: [
                             BoxShadow(
                               color: const Color(0xFFF14966).withOpacity(0.3),
                               blurRadius: 15,
                               offset: const Offset(0, 8),
                             ),
                           ],
                         ),
                         child: ElevatedButton(
                           onPressed: _submitProduct,
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.transparent,
                             shadowColor: Colors.transparent,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(30),
                             ),
                           ),
                           child: Text(
                             widget.product == null ? 'Add Product' : 'Save Changes', 
                             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                           ),
                         ),
                       ),
                       if (widget.product != null) ...[
                         SizedBox(height: 16),
                         ElevatedButton.icon(
                            icon: Icon(Icons.delete_forever, color: Colors.white),
                            label: Text('Delete Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _deleteProduct,
                         ),
                       ]
                     ],
                   )
            ],
          ),
        ),
      ),
    );
  }
}
