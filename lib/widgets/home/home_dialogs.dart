// lib/widgets/home/home_dialogs.dart
import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';
import '../../models/meal_type.dart';
import '../common/primary_button.dart';
import '../common/secondary_button.dart';
import '../../screens/add_food_screen.dart';
import '../../screens/meal_estimator_screen.dart';
import '../../controllers/home_controller.dart'; 
import 'package:provider/provider.dart';

class HomeDialogs {

  static Future<void> showDeleteFavoriteDialog(BuildContext context, FoodItem favorite, Function onConfirm) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer le favori ?'),
          content: Text('Voulez-vous vraiment supprimer "${favorite.name}" de vos favoris ?'),
          actions: <Widget>[
            SecondaryButton(
              text: 'Annuler',
              onPressed: () => Navigator.of(context).pop(),
            ),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showSaveMealDialog(BuildContext context, MealType mealType, List<FoodItem> items, Function(String) onConfirm) async {
    final nameController = TextEditingController();
    nameController.text = '${mealType.frenchName} favori';
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sauvegarder le repas'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom du repas'),
            autofocus: true,
          ),
          actions: [
            SecondaryButton(
              text: 'Annuler',
              onPressed: () => Navigator.of(context).pop(),
            ),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  onConfirm(nameController.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showCopyMealConfirmation(BuildContext context, MealType mealType, Function onConfirm) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Copier le repas d\'hier ?'),
          content: Text('Voulez-vous ajouter tous les aliments du ${mealType.frenchName.toLowerCase()} d\'hier à votre journal d\'aujourd\'hui ?'),
          actions: <Widget>[
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.of(context).pop()),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showAddFavoriteToMealDialog(BuildContext context, FoodItem favorite, Function(MealType) onMealSelected) async {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
            child: Wrap(
              children: <Widget>[
                const ListTile(title: Text('Ajouter ce favori à...', style: TextStyle(fontWeight: FontWeight.bold))),
                const Divider(),
                ...MealType.values.map((meal) => ListTile(
                  title: Text(meal.frenchName),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMealSelected(meal);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showAddSavedMealToMealDialog(BuildContext context, SavedMeal meal, Function(MealType) onMealSelected) async {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
            child: Wrap(
              children: <Widget>[
                ListTile(title: Text('Ajouter "${meal.name}" à...', style: const TextStyle(fontWeight: FontWeight.bold))),
                const Divider(),
                ...MealType.values.map((m) => ListTile(
                  title: Text(m.frenchName),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMealSelected(m);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showMealSelection(BuildContext context, DateTime selectedDate) async {
    final homeController = context.read<HomeController>();

    void navigateToEstimator(MealType mealType) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MealEstimatorScreen(
            mealType: mealType,
            selectedDate: selectedDate,
          ),
        ),
      ).then((result) {
        if (result != null && result is FoodItem) {
          homeController.submitFood(result).then((_) {
            homeController.refreshData(selectedDate);
          });
        }
      });
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Estimer un plat'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      builder: (mealCtx) => Wrap(
                        children: MealType.values.map((meal) => ListTile(
                          title: Text('Ajouter à : ${meal.frenchName}'),
                          onTap: () {
                            Navigator.pop(mealCtx);
                            navigateToEstimator(meal);
                          },
                        )).toList(),
                      ),
                    );
                  },
                ),
                const Divider(thickness: 1),
                ...MealType.values.map((meal) {
                  return ListTile(
                    title: Text('Ajouter à : ${meal.frenchName}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFoodScreen(mealType: meal, selectedDate: selectedDate),
                        ),
                      ).then((_) => homeController.refreshData(selectedDate));
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- NOUVELLE MÉTHODE POUR LA BOÎTE DE DIALOGUE DE QUANTITÉ ---
  static Future<void> showQuantityDialog(
    BuildContext context,
    FoodItem favorite,
    MealType meal,
    DateTime date,
    Function(FoodItem) onConfirm,
  ) async {
    final quantityController = TextEditingController(text: '100');
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quelle quantité pour "${favorite.name}" ?'),
          content: TextField(
            controller: quantityController,
            decoration: const InputDecoration(labelText: 'Quantité en grammes'),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.pop(context)),
            PrimaryButton(
              text: 'Ajouter',
              onPressed: () {
                final quantity = double.tryParse(quantityController.text);
                if (quantity != null && quantity > 0) {
                  // --- LA LOGIQUE CLÉ EST ICI ---
                  // On crée une nouvelle instance de FoodItem à partir du favori,
                  // mais en spécifiant une nouvelle date, un nouveau type de repas,
                  // et en forçant l'ID à null pour que la BDD en crée un nouveau.
                  final itemToLog = favorite.copyWith(
                    quantity: quantity,
                    mealType: meal,
                    date: date, // On assigne la date du jour
                    forceIdToNull: true,   // On s'assure que c'est bien une nouvelle entrée
                  );
                  // --- FIN DE LA LOGIQUE CLÉ ---
                  
                  onConfirm(itemToLog);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showDeleteSavedMealDialog(BuildContext context, SavedMeal meal, Function onConfirm) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer ce repas ?'),
          content: Text('Voulez-vous vraiment supprimer le repas "${meal.name}" ? Cette action est irréversible.'),
          actions: <Widget>[
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.of(context).pop()),
            PrimaryButton(
              text: 'Supprimer',
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showEditQuantityDialog(BuildContext context, FoodItem item, Function(double) onConfirm) async {
    final quantityController = TextEditingController(text: item.quantity.toString());
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Modifier "${item.name}"'),
          content: TextField(
            controller: quantityController,
            decoration: const InputDecoration(labelText: 'Nouvelle quantité (g)'),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: <Widget>[
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.of(context).pop()),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () {
                final newQuantity = double.tryParse(quantityController.text);
                if (newQuantity != null && newQuantity > 0) {
                  Navigator.of(context).pop();
                  onConfirm(newQuantity);
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showFoodItemActionsMenu(
    BuildContext context,
    FoodItem item, {
    required VoidCallback onDelete,
    required VoidCallback onAddToFavorites,
    // La signature est maintenant correcte
    required Function(double) onEdit,
  }) async {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(item.name ?? 'Actions', style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier la quantité'),
                onTap: () {
                  Navigator.pop(context);

                  showEditQuantityDialog(context, item, onEdit);
                  // On appelle notre nouvelle méthode de dialogue
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border_outlined),
                title: const Text('Ajouter aux favoris'),
                onTap: () {
                  Navigator.pop(context);
                  onAddToFavorites();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text('Supprimer du journal', style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> showClearAllDialog(BuildContext context, bool isFavoritesTab, Function onConfirm) async {
    final String title = isFavoritesTab ? 'Vider les favoris ?' : 'Vider les repas ?';
    final String content = isFavoritesTab 
        ? 'Tous vos favoris seront supprimés. Cette action est irréversible.'
        : 'Tous vos repas sauvegardés seront supprimés. Cette action est irréversible.';

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.pop(ctx)),
            PrimaryButton(
              text: 'Tout supprimer',
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  
  
}