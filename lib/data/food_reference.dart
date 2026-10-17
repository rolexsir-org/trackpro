import '../models/models.dart';

/// Static reference table for quick-adding a calorie entry.
///
/// This is **reference data, not user data**: a fixed list of common foods with
/// approximate energy values, shipped with the app so the calorie tracker is
/// usable offline on day one. It is never written to `daily_entries`, never
/// counted in totals, and never presented as something the user logged.
///
/// A future build can replace this with a queryable food database without
/// touching the storage layer: the only contract is `id`, `name`, `kcal`.
class FoodReference {
  const FoodReference._();

  /// Values are approximate kcal per typical serving, rounded. They are labelled
  /// "approx." in the UI — a tracker that implies laboratory precision it does
  /// not have is worse than one that admits it is estimating.
  static const List<FoodItem> common = <FoodItem>[
    FoodItem('Poha + chai', 320, '🍚'),
    FoodItem('Chicken salad', 410, '🥗'),
    FoodItem('Filter coffee', 90, '☕️'),
    FoodItem('Almonds (10)', 160, '🥜'),
    FoodItem('Dal, roti, sabzi', 430, '🍛'),
    FoodItem('Curd rice', 350, '🍚'),
    FoodItem('Masala dosa', 390, '🥞'),
    FoodItem('Egg bhurji + toast', 380, '🍳'),
    FoodItem('Banana', 105, '🍌'),
    FoodItem('Protein shake', 210, '🥛'),
  ];

  static FoodItem? byName(String name) {
    for (final f in common) {
      if (f.name == name) return f;
    }
    return null;
  }
}
