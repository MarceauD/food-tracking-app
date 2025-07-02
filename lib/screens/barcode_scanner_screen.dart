// lib/screens/barcode_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/add_food_controller.dart'; // Importer le controller

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
   bool _isTorchOn = false;

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

        case ProductResultStatus.timeoutError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La requête a expiré. Veuillez réessayer.')),
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
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 250,
      height: 150,
    );

    return Scaffold(
      // On retire l'AppBar pour une immersion totale
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Couche 1 : La vue de la caméra
          MobileScanner(
            // La fenêtre de scan permet au scanner d'être plus performant
            scanWindow: scanWindow,
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          
          // Couche 2 : L'overlay semi-transparent avec le trou
          CustomPaint(
            painter: ScannerOverlay(scanWindow),
          ),
          
          // Couche 3 : Les boutons et textes d'aide
          Positioned(
            top: 60,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 60,
            right: 20,
            child: IconButton(
              color: _isTorchOn ? Colors.yellow.shade700 : Colors.white,
              icon: Icon(_isTorchOn ? Icons.flash_on_outlined : Icons.flash_off_outlined),
              onPressed: () async {
               await  _scannerController.toggleTorch();
               setState((){
                _isTorchOn = !_isTorchOn;
               });
              },
              tooltip: 'Lampe torche',
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Visez le code-barres',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRect(scanWindow);

    // On crée un fond semi-transparent qui couvre tout l'écran
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5);

    // On combine les deux formes pour "creuser" la fenêtre de scan dans le fond
    final cutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(cutout, backgroundPaint);

    // On dessine une bordure autour de la fenêtre de scan
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(scanWindow, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}