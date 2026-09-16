import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class StockManagementScreen extends StatefulWidget {
  @override
  _StockManagementScreenState createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _stocks = [];
  List<dynamic> _ingredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final stockResponse = await _apiService.get('/products/baker_stock/');
      final ingredientResponse = await _apiService.get('/products/ingredients/');
      setState(() {
        _stocks = stockResponse.data;
        _ingredients = ingredientResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stock data: $e')),
      );
    }
  }

  Future<void> _showStockDialog({Map<String, dynamic>? stock}) async {
    bool isUpdate = stock != null;
    int? selectedIngredientId = isUpdate ? stock['ingredient'] : null;
    final quantityController = TextEditingController(text: isUpdate ? stock['quantity'].toString() : '');
    final thresholdController = TextEditingController(text: isUpdate ? stock['low_stock_threshold'].toString() : '0.0');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isUpdate ? 'Update Stock' : 'Add Stock',
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
                        items: _ingredients
                            .where((ing) => !_stocks.any((s) => s['ingredient'] == ing['id']))
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
                      const SizedBox(height: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Ingredient'),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showCreateIngredientDialog();
                          _showStockDialog();
                        },
                      ),
                    ] else ...[
                      Text('Ingredient: ${stock['ingredient_name']} (${stock['ingredient_unit']})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                    const SizedBox(height: 15),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: thresholdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Low Stock Threshold',
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a quantity')));
                      return;
                    }

                    try {
                      final data = {
                        if (!isUpdate) 'ingredient': selectedIngredientId,
                        'quantity': quantityController.text,
                        'low_stock_threshold': thresholdController.text,
                      };

                      if (isUpdate) {
                        await _apiService.patch('/products/baker_stock/${stock['id']}/', data);
                      } else {
                        await _apiService.post('/products/baker_stock/', data);
                      }
                      Navigator.pop(context);
                      _fetchData();
                    } catch (e) {
                      String errMsg = e.toString();
                      if (e is DioException) {
                        errMsg = e.response?.data?.toString() ?? e.message ?? errMsg;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save stock: $errMsg')),
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

  Future<void> _showCreateIngredientDialog() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Ingredient', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name (e.g., Sugar)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unitController,
              decoration: InputDecoration(labelText: 'Unit (e.g., kg, liters, pcs)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || unitController.text.isEmpty) return;
              try {
                await _apiService.post('/products/ingredients/', {
                  'name': nameController.text,
                  'unit': unitController.text,
                });
                Navigator.pop(context);
                await _fetchData(); // Refresh ingredients
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStock(int id) async {
    try {
      await _apiService.delete('/products/baker_stock/$id/');
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete stock: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1E6),
      appBar: AppBar(
        title: Text('Stock Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE07A5F),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE07A5F)))
          : _stocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No stock tracked yet.', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _stocks.length,
                  itemBuilder: (context, index) {
                    final stock = _stocks[index];
                    final double quantity = double.tryParse(stock['quantity'].toString()) ?? 0;
                    final double threshold = double.tryParse(stock['low_stock_threshold'].toString()) ?? 0;
                    final bool isLowStock = quantity <= threshold;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isLowStock ? const Color(0xFFFFE5E5) : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLowStock ? Colors.red[100] : const Color(0xFFF4A261).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLowStock ? Icons.warning_amber_rounded : Icons.kitchen,
                            color: isLowStock ? Colors.red[800] : const Color(0xFFE07A5F),
                          ),
                        ),
                        title: Text(
                          stock['ingredient_name'] ?? 'Unknown',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF4A2511)),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Current Stock: ${stock['quantity']} ${stock['ingredient_unit']}',
                              style: GoogleFonts.inter(
                                color: isLowStock ? Colors.red[700] : Colors.grey[700],
                                fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              'Low Threshold: ${stock['low_stock_threshold']} ${stock['ingredient_unit']}',
                              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showStockDialog(stock: stock),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteStock(stock['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStockDialog(),
        backgroundColor: const Color(0xFFE07A5F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
