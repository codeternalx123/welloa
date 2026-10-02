// lib/widgets/restaurant_meal_card.dart
// UI Widget: Restaurant Meal Suggestion Card with Verification Status

import 'package:flutter/material.dart';
import '../services/transparent_kitchen_indexer.dart';
import '../services/restaurant_meal_matcher.dart';
import '../services/deep_link_cart_fulfillment.dart';

/// Beautiful card displaying verified restaurant meal with:
/// - VERIFIED/NOT VERIFIED badge
/// - Metabolic safety score
/// - Price and deep-link button
/// - Alternative meal suggestions
class RestaurantMealCard extends StatelessWidget {
  final ScoredMealMatch mealMatch;
  final DeepLinkResult deepLink;
  final VoidCallback? onOrderPressed;
  
  const RestaurantMealCard({
    super.key,
    required this.mealMatch,
    required this.deepLink,
    this.onOrderPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Restaurant name + verification badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    mealMatch.restaurant.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildVerificationBadge(mealMatch.meal.isVerified),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Meal name
            Text(
              mealMatch.meal.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              mealMatch.meal.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 16),
            
            // Metabolic info row
            Row(
              children: [
                _buildMetricChip(
                  icon: Icons.trending_up,
                  label: '${mealMatch.meal.predictedSpikeGlucose?.toStringAsFixed(0) ?? '?'} mg/dL',
                  color: _getSpikeColor(mealMatch.meal.predictedSpikeGlucose),
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  icon: Icons.star,
                  label: mealMatch.scoreLabel,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  icon: Icons.restaurant,
                  label: mealMatch.meal.cuisine,
                  color: Colors.blue,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Verification details
            if (mealMatch.meal.isVerified) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recipe verified: ${mealMatch.meal.ingredients.length} ingredients',
                      style: TextTheme.of(context).bodySmall?.copyWith(
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  if (mealMatch.meal.recipeUrl != null)
                    TextButton(
                      onPressed: () {
                        // Open recipe URL
                      },
                      child: const Text('View Recipe'),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No online recipe found - estimated values',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Price and order button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mealMatch.meal.currency} ${mealMatch.meal.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onOrderPressed,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Order on ${deepLink.platformDisplayName}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            
            // Alternatives section
            if (mealMatch.meal.alternatives.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Better Options in Same Category:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...mealMatch.meal.alternatives.take(2).map((alt) => _buildAlternativeTile(context, alt)),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.info_outline,
            size: 16,
            color: isVerified ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'VERIFIED' : 'NOT VERIFIED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isVerified ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSpikeColor(double? spike) {
    if (spike == null) return Colors.grey;
    if (spike < 30) return Colors.green;
    if (spike < 45) return Colors.lightGreen;
    if (spike < 60) return Colors.orange;
    return Colors.red;
  }
  
  Widget _buildAlternativeTile(BuildContext context, AlternativeMeal alternative) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alternative.meal.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${alternative.restaurant.name} • ${alternative.spikeImprovement.toStringAsFixed(0)} mg/dL lower spike',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${alternative.meal.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen dialog showing multiple restaurant suggestions
class RestaurantMealSuggestionsDialog extends StatelessWidget {
  final String craving;
  final List<RestaurantSuggestion> suggestions;
  final Function(DeepLinkResult) onOrderPressed;
  
  const RestaurantMealSuggestionsDialog({
    super.key,
    required this.craving,
    required this.suggestions,
    required this.onOrderPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Craving: "$craving"'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RestaurantMealCard(
                mealMatch: suggestion.match,
                deepLink: suggestion.deepLink,
                onOrderPressed: () {
                  onOrderPressed(suggestion.deepLink);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// Import placeholder models (these should match actual service models)
class RestaurantSuggestion {
  final ScoredMealMatch match;
  final DeepLinkResult deepLink;
  
  const RestaurantSuggestion({
    required this.match,
    required this.deepLink,
  });
}
