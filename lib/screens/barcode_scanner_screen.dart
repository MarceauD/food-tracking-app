import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../models/food_item.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Le contrôleur est toujours utile pour gérer la caméra (flash, etc.)
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  // Méthode pour traiter le code-barres détecté
  // La signature a changé : on reçoit un BarcodeCapture directement
  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    // La logique pour éviter les traitements multiples reste la même
    if (_isProcessing) return;

    // On récupère le premier code-barres trouvé dans la capture
    final Barcode? barcode = capture.barcodes.firstOrNull;

    if (barcode == null || barcode.rawValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lire le code-barres')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final String code = barcode.rawValue!;
    
    // La logique d'affichage de la popup de chargement et de l'appel API ne change pas
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _fetchProductData(code);
  }

  // La méthode _fetchProductData reste identique à la version précédente
  Future<void> _fetchProductData(String barcode) async {
    try {
      final ProductQueryConfiguration config = ProductQueryConfiguration(
        barcode,
        version: ProductQueryVersion.v3,
        language: OpenFoodFactsLanguage.FRENCH,
        fields: [ProductField.ALL],
      );

      final ProductResultV3 result = await OpenFoodAPIClient.getProductV3(config);

      if (!mounted) return;
      Navigator.of(context).pop(); // Ferme la popup de chargement

      if (result.product != null) {
        final Product product = result.product!;
        
        final FoodItem foodItem = FoodItem(
          name: product.productName ?? 'Produit inconnu',
          caloriesPer100g: product.nutriments?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams) ?? 0.0,
          proteinPer100g: product.nutriments?.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0,
          carbsPer100g: product.nutriments?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0,
          fatPer100g: product.nutriments?.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0,
          quantity: 100,
        );
        
        Navigator.of(context).pop(foodItem);

      } else {
        throw Exception('Produit non trouvé');
      }
    } catch (e) {
      if(mounted) {
        print("ERREUR DÉTAILLÉE : $e");
        if (Navigator.of(context).canPop()) {
           Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : Produit non trouvé ou problème réseau')),
        );
      }
      
      Future.delayed(const Duration(seconds: 2), () {
        if(mounted) setState(() { _isProcessing = false; });
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un code-barres')),
      body: MobileScanner(
        // Le paramètre s'appelle maintenant `onDetect`
        onDetect: _onBarcodeDetected, 
        controller: _scannerController,
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}