// lib/screens/meal_estimator_screen.dart
import 'package:flutter/material.dart';
import '../helpers/meal_estimator_service.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../widgets/common/primary_button.dart';

class MealEstimatorScreen extends StatefulWidget {
  final MealType mealType;
  final DateTime selectedDate;

  const MealEstimatorScreen({
    super.key,
    required this.mealType,
    required this.selectedDate,
  });

  @override
  State<MealEstimatorScreen> createState() => _MealEstimatorScreenState();
}

class _MealEstimatorScreenState extends State<MealEstimatorScreen> {
  // Variables d'état pour suivre les choix de l'utilisateur
  PlatType? _selectedPlatType = PlatType.sale;
  final Set<Enum> _selectedComponents = {};
  final Map<Enum, PortionSize> _portionSizes = {};
  final Set<Enum> _selectedModifiers = {};

  // Méthode pour soumettre le formulaire et retourner l'aliment estimé
  void _submitEstimation() {
    if (_selectedPlatType == null || _selectedComponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un composant.')),
      );
      return;
    }

    final estimatedFood = MealEstimatorService.estimateMeal(
      mealType: widget.mealType,
      date: widget.selectedDate,
      platType: _selectedPlatType!,
      components: _selectedComponents,
      portionSizes: _portionSizes,
      modifiers: _selectedModifiers,
    );

    Navigator.of(context).pop(estimatedFood);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimer un Plat'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Quel type de plat estimez-vous ?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<PlatType>(
            segments: const [
              ButtonSegment(value: PlatType.sale, label: Text('Plat Salé'), icon: Icon(Icons.ramen_dining_outlined)),
              ButtonSegment(value: PlatType.sucre, label: Text('Dessert'), icon: Icon(Icons.cake_outlined)),
              ButtonSegment(value: PlatType.boisson, label: Text('Boisson'), icon: Icon(Icons.local_cafe_outlined)),
            ],
            selected: _selectedPlatType != null ? {_selectedPlatType!} : {},
            onSelectionChanged: (selection) => setState(() {
              _selectedPlatType = selection.first;
              _selectedComponents.clear();
              _portionSizes.clear();
              _selectedModifiers.clear();
            }),
          ),

          // Affiche le formulaire correspondant au type de plat choisi
          if (_selectedPlatType != null) ...[
            const Divider(height: 32),
            if (_selectedPlatType == PlatType.sale) ..._buildSaleWidgets(),
            if (_selectedPlatType == PlatType.sucre) ..._buildSucreWidgets(),
            if (_selectedPlatType == PlatType.boisson) ..._buildBoissonWidgets(),
          ],

          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Calculer et Ajouter',
            onPressed: _selectedPlatType != null && _selectedComponents.isNotEmpty ? _submitEstimation : null,
          ),
        ],
      ),
    );
  }

  // --- Méthodes de construction pour chaque formulaire ---

  List<Widget> _buildSaleWidgets() {
    return [
      Text('De quoi était composé le plat ?', style: Theme.of(context).textTheme.titleMedium),
      ...SaleComponent.values.map((component) => CheckboxListTile(
        title: Text(component.frenchName),
        value: _selectedComponents.contains(component),
        onChanged: (val) => setState(() {
          if (val!) {
            _selectedComponents.add(component);
            _portionSizes[component] = PortionSize.normal;
          } else {
            _selectedComponents.remove(component);
            _portionSizes.remove(component);
          }
        }),
      )),
      if (_selectedComponents.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Quelles étaient les quantités ?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._selectedComponents.whereType<SaleComponent>().map((c) => _buildPortionSelector(c, c.frenchName)),
      ],
      const SizedBox(height: 16),
      Text('Y avait-il des extras ?', style: Theme.of(context).textTheme.titleMedium),
      ...SaleModifier.values.map((modifier) => CheckboxListTile(
        title: Text(modifier.frenchName),
        value: _selectedModifiers.contains(modifier),
        onChanged: (val) => setState(() => val! ? _selectedModifiers.add(modifier) : _selectedModifiers.remove(modifier)),
      )),
    ];
  }

  List<Widget> _buildSucreWidgets() {
    return [
      Text('De quoi était composé le dessert ?', style: Theme.of(context).textTheme.titleMedium),
      ...SucreComponent.values.map((component) => CheckboxListTile(
        title: Text(component.frenchName),
        value: _selectedComponents.contains(component),
        onChanged: (val) => setState(() => val! ? _selectedComponents.add(component) : _selectedComponents.remove(component)),
      )),
      const SizedBox(height: 16),
    Text('Y avait-il des extras ?', style: Theme.of(context).textTheme.titleMedium),
    ...SucreModifier.values.map((modifier) => CheckboxListTile(
      title: Text(modifier.frenchName),
      value: _selectedModifiers.contains(modifier),
      onChanged: (val) => setState(() => val! ? _selectedModifiers.add(modifier) : _selectedModifiers.remove(modifier)),
    )),
    ];
  }

  List<Widget> _buildBoissonWidgets() {
    return [
      Text('Quel type de boisson ?', style: Theme.of(context).textTheme.titleMedium),
      ...BoissonComponent.values.map((component) => RadioListTile<BoissonComponent>(
        title: Text(component.frenchName),
        value: component,
        groupValue: _selectedComponents.firstOrNull as BoissonComponent?,
        onChanged: (val) => setState(() {
          _selectedComponents.clear();
          if (val != null) _selectedComponents.add(val);
        }),
      )),
      const SizedBox(height: 16),
    Text('Y avait-il des extras ?', style: Theme.of(context).textTheme.titleMedium),
    ...BoissonModifier.values.map((modifier) => CheckboxListTile(
      title: Text(modifier.frenchName),
      value: _selectedModifiers.contains(modifier),
      onChanged: (val) => setState(() => val! ? _selectedModifiers.add(modifier) : _selectedModifiers.remove(modifier)),
    )),
    ];
  }

  // --- Widget d'aide réutilisable pour le sélecteur de portions ---
  Widget _buildPortionSelector(Enum component, String frenchName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            frenchName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPortionButton(component, PortionSize.small, 'Petite'),
              _buildPortionButton(component, PortionSize.normal, 'Normale'),
              _buildPortionButton(component, PortionSize.large, 'Grande'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortionButton(Enum component, PortionSize size, String label) {
    final bool isSelected = _portionSizes[component] == size;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _portionSizes[component] = size),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black))),
        ),
      ),
    );
  }
}