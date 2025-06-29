// lib/screens/barcode_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/add_food_controller.dart'; // Importer le controller
import '../models/food_item.dart';

class BarcodeScannerScreen extends StatefulWidget {
  // On s'assure qu'il reçoit bien le controller en paramètre
  final AddFoodController controller;

  const BarcodeScannerScreen({
    super.key,
    required this.controller,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  // L'ancienne méthode _fetchProductData qui était dans ce fichier peut être supprimée.

  // Voici la nouvelle méthode _onBarcodeDetected, qui utilise le controller.
  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final Barcode? barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() { _isProcessing = true; });

    final String code = barcode.rawValue!;
    
    // Affiche la popup de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // ON APPELLE NOTRE CONTROLLER INTELLIGENT
    final result = await widget.controller.fetchProductFromBarcode(code);

    if (!mounted) return;
    Navigator.of(context).pop(); // Ferme la popup de chargement DANS TOUS LES CAS

    // ON UTILISE UN SWITCH POUR TRAITER PROPREMENT CHAQUE CAS DE RÉPONSE
    switch (result.status) {
      
      case ProductResultStatus.success:
        // Succès : on renvoie le FoodItem déjà préparé par le controller
        Navigator.of(context).pop(result.foodItem);
        break;

      case ProductResultStatus.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit non trouvé dans la base de données.')),
        );
        break;

      case ProductResultStatus.incompleteData:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit trouvé, mais données nutritionnelles manquantes.')),
        );
        break;

      case ProductResultStatus.networkError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau. Vérifiez votre connexion internet.')),
        );
        break;
    }
    
    // Après une erreur, on réactive le scanner pour un nouvel essai
    if (result.status != ProductResultStatus.success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isProcessing = false; });
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un code-barres')),
      body: MobileScanner(
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