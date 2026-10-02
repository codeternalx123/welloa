import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/currency_utils.dart';
import '../providers/subscription_provider.dart';
import '../widgets/feature_restriction_widgets.dart';
import 'user_profile_screen.dart';
import 'subscription_screen.dart';

/// Family Meal Planning Screen with Budget and Currency Support
class FamilyMealPlanningScreen extends StatefulWidget {
  const FamilyMealPlanningScreen({super.key});

  @override
  State<FamilyMealPlanningScreen> createState() =>
      _FamilyMealPlanningScreenState();
}

class _FamilyMealPlanningScreenState extends State<FamilyMealPlanningScreen> {
  String _selectedCurrency = 'NGN'; // Default to Nigerian Naira
  double _budget = 30000; // Default budget for family
  int _days = 7;
  int _familySize = 4;
  String _dietType = 'balanced';

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, child) {
        // Check if user has family plan access
        if (!subProvider.canAccessFamilyProfiles) {
          return _buildPremiumRequiredScreen();
        }

        return _buildMainContent();
      },
    );
  }

  Widget _buildPremiumRequiredScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Meal Planning'),
        backgroundColor: const Color(0xFF9B59B6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9B59B6), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: Color(0xFF9B59B6),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FAMILY PLAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create shared meal plans for your family with personalized nutrition goals (Premium: 7 members, Ultra: 10).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureList(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF9B59B6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'UPGRADE TO FAMILY PLAN',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
                'Premium: up to 7 members · Ultra: up to 10 members',
      'Shared meal planning',
      'Family grocery lists',
      'Individual nutrition goals',
      // 'Family health dashboard', // TODO: Not implemented
    ];

    return Column(
      children: features
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Meal Planning'),
        backgroundColor: const Color(0xFF9B59B6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9B59B6), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        size: 60,
                        color: Color(0xFF9B59B6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Family Meal Plans',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create meal plans for your whole family within budget',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Currency Selection
                _buildCard(
                  'Select Currency',
                  Icons.currency_exchange,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose your preferred currency',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: CurrencyUtils.availableCurrencies
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Row(
                                  children: [
                                    Text(
                                      CurrencyUtils.getCurrencySymbolByCode(
                                        code,
                                      ),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${CurrencyUtils.getCurrencyNameByCode(code)} ($code)',
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrency = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Family Size
                _buildCard(
                  'Family Size',
                  Icons.people,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_familySize people',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _familySize.toDouble(),
                        min: 2,
                        max: 10,
                        divisions: 8,
                        activeColor: const Color(0xFF9B59B6),
                        label: '$_familySize people',
                        onChanged: (value) {
                          setState(() {
                            _familySize = value.toInt();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Budget Input
                _buildCard(
                  'Set Your Budget',
                  Icons.attach_money,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly budget: ${CurrencyUtils.formatCurrency(_budget, _selectedCurrency)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Per person: ${CurrencyUtils.formatCurrency(_budget / _familySize, _selectedCurrency)}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _budget,
                        min: 5000,
                        max: 200000,
                        divisions: 195,
                        activeColor: const Color(0xFF9B59B6),
                        label: CurrencyUtils.formatCurrency(
                          _budget,
                          _selectedCurrency,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _budget = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Days Selection
                _buildCard(
                  'Plan Duration',
                  Icons.calendar_today,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_days days',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [3, 5, 7, 14, 30].map((days) {
                          return ChoiceChip(
                            label: Text(
                              '$days days',
                              style: const TextStyle(fontSize: 9),
                            ),
                            selected: _days == days,
                            selectedColor: const Color(0xFF9B59B6),
                            labelStyle: TextStyle(
                              color: _days == days
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _days = days;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Diet Type
                _buildCard(
                  'Diet Preferences',
                  Icons.restaurant,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select dietary preferences for the family',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children:
                            [
                              'balanced',
                              'kid-friendly',
                              'traditional',
                              'vegetarian',
                              'mixed',
                            ].map((type) {
                              return ChoiceChip(
                                label: Text(
                                  type,
                                  style: const TextStyle(fontSize: 9),
                                ),
                                selected: _dietType == type,
                                selectedColor: const Color(0xFF9B59B6),
                                labelStyle: TextStyle(
                                  color: _dietType == type
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _dietType = type;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _generateFamilyMealPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Generate Family Meal Plan',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF9B59B6)),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _generateFamilyMealPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generating $_days-day meal plan for $_familySize people with ${CurrencyUtils.formatCurrency(_budget, _selectedCurrency)} budget...',
        ),
        backgroundColor: const Color(0xFF9B59B6),
      ),
    );
    // TODO: Implement family meal plan generation with AI service
  }
}
