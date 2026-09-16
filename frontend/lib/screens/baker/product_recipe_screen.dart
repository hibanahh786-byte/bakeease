import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';

class ProductRecipeScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductRecipeScreen({Key? key, required this.productId, required this.productName}) : super(key: key);

  @override
  _ProductRecipeScreenState createState() => _ProductRecipeScreenState();
}

class _ProductRecipeScreenState extends State<ProductRecipeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _recipeIngredients = [];
  List<dynamic> _allIngredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final recipeResponse = await _apiService.get('/products/product_ingredients/?product=${widget.productId}');
      final ingredientResponse = await _apiService.get('/products/ingredients/');
      setState(() {
        _recipeIngredients = recipeResponse.data;
        _allIngredients = ingredientResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recipe data: $e')),
      );
    }
  }

  Future<void> _showRecipeIngredientDialog({Map<String, dynamic>? item}) async {
    bool isUpdate = item != null;
    int? selectedIngredientId = isUpdate ? item['ingredient'] : null;
    final quantityController = TextEditingController(text: isUpdate ? item['quantity_required'].toString() : '');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isUpdate ? 'Update Recipe Item' : 'Add Recipe Item',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF4A2511))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUpdate) ...[
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Select Ingredient',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        value: selectedIngredientId,
                        items: _allIngredients
                            .where((ing) => !_recipeIngredients.any((s) => s['ingredient'] == ing['id']))
                            .map((ing) {
                          return DropdownMenuItem<int>(
                            value: ing['id'],
                            child: Text('${ing['name']} (${ing['unit']})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedIngredientId = val;
                          });
                        },
                      ),
                    ] else ...[
                      Text('Ingredient: ${item['ingredient_name']} (${item['ingredient_unit']})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                    const SizedBox(height: 15),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity Required',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!isUpdate && selectedIngredientId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an ingredient')));
                      return;
                    }
                    if (quantityController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the quantity required')));
                      return;
                    }

                    try {
                      final data = {
                        if (!isUpdate) 'product': widget.productId,
                        if (!isUpdate) 'ingredient': selectedIngredientId,
                        'quantity_required': quantityController.text,
                      };

                      if (isUpdate) {
                        await _apiService.patch('/products/product_ingredients/${item['id']}/', data);
                      } else {
                        await _apiService.post('/products/product_ingredients/', data);
                      }
                      Navigator.pop(context);
                      _fetchData();
                    } catch (e) {
                      String errMsg = e.toString();
                      if (e is DioException) {
                        errMsg = e.response?.data?.toString() ?? e.message ?? errMsg;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save recipe item: $errMsg')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteRecipeItem(int id) async {
    try {
      await _apiService.delete('/products/product_ingredients/$id/');
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1E6),
      appBar: AppBar(
        title: Text('Recipe: ${widget.productName}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE07A5F),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE07A5F)))
          : _recipeIngredients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No ingredients added to recipe yet.', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16)),
                      Text('Adding an ingredient will automatically deduct it from your stock.', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _recipeIngredients.length,
                  itemBuilder: (context, index) {
                    final item = _recipeIngredients[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4A261).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_basket, color: Color(0xFFE07A5F)),
                        ),
                        title: Text(
                          item['ingredient_name'] ?? 'Unknown',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF4A2511)),
                        ),
                        subtitle: Text(
                          'Requires: ${item['quantity_required']} ${item['ingredient_unit']}',
                          style: GoogleFonts.inter(color: Colors.grey[700]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showRecipeIngredientDialog(item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteRecipeItem(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecipeIngredientDialog(),
        backgroundColor: const Color(0xFFE07A5F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Ingredient', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
