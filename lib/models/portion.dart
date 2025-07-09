class Portion {
  final String name;
  final double weightInGrams;

  Portion({
    required this.name,
    required this.weightInGrams,
  });

  // NOUVELLE MÉTHODE factory pour créer une instance depuis une Map (JSON)
  factory Portion.fromJson(Map<String, dynamic> json) {
    return Portion(
      name: json['portion_name'] as String,
      weightInGrams: (json['weight_in_grams'] as num).toDouble(),
    );
  }
}