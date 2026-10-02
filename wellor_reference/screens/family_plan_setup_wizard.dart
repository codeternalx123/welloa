import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_plan_models.dart';
import '../providers/family_profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/feature_restriction_widgets.dart';
import '../utils/currency_utils.dart';

class FamilyPlanSetupWizard extends StatefulWidget {
  const FamilyPlanSetupWizard({super.key});

  @override
  State<FamilyPlanSetupWizard> createState() => _FamilyPlanSetupWizardState();
}

class _FamilyPlanSetupWizardState extends State<FamilyPlanSetupWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Step 1: Family Size & Budget
  int _familySize = 2;
  double _monthlyBudget = 20000;
  String _budgetCurrency = 'KES';
  String _budgetLevel = 'Medium';
  
  // Budget text controller for manual editing
  late TextEditingController _budgetController;
  
  // Step 2: Shared Preferences
  List<String> _sharedAllergies = [];
  String _preferredCuisine = 'Mixed';
  String _cookingSkillLevel = 'Intermediate';
  int _mealsPerDay = 3;
  
  // Step 3: Family Members
  List<FamilyMember> _familyMembers = [];
  
  final List<String> _commonDiseases = [
    'Diabetes', 'Hypertension', 'Heart Disease', 'High Cholesterol',
    'PCOS', 'Thyroid', 'Celiac Disease', 'IBS', 'Kidney Disease',
    'Arthritis', 'Obesity', 'Anemia', 'None'
  ];
  
  final List<String> _healthGoals = [
    'Weight Loss', 'Muscle Gain', 'Maintenance', 'Heart Health',
    'Blood Sugar Control', 'Digestive Health', 'Energy Boost',
    'Better Sleep', 'Skin Health', 'Bone Health'
  ];
  
  final List<String> _commonAllergies = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat', 'Soy',
    'Fish', 'Shellfish', 'Sesame', 'None'
  ];
  
  final List<String> _flavors = [
    'Sweet', 'Salty', 'Sour', 'Bitter', 'Umami', 'Spicy', 'Balanced'
  ];
  
  final List<String> _dietTypes = [
    'Balanced', 'Low-Carb', 'High-Protein', 'Vegetarian', 'Vegan',
    'Keto', 'Paleo', 'Mediterranean'
  ];
  
  final List<String> _activityLevels = [
    'Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'
  ];

  final List<String> _cuisines = [
    'Mixed', 'Kenyan', 'Mediterranean', 'Asian', 'American',
    'Mexican', 'Indian', 'Italian', 'African'
  ];

  final List<String> _cookingSkills = [
    'Beginner', 'Intermediate', 'Advanced', 'Expert'
  ];

  final List<String> _costSavingPreferences = [
    'Seasonal Ingredients', 'Bulk Buying', 'Leftovers Planning',
    'Budget Proteins', 'Local Produce', 'Minimize Waste'
  ];

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(text: _monthlyBudget.toStringAsFixed(0));
    _initializeFamilyMembers();
  }

  void _initializeFamilyMembers() {
    _familyMembers = List.generate(
      _familySize,
      (index) => FamilyMember(
        id: 'member_$index',
        name: 'Member ${index + 1}',
        age: 30,
        gender: 'Other',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Plan Setup'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 4,
            backgroundColor: Colors.grey[300],
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          _buildFamilySizeAndBudgetStep(),
          _buildSharedPreferencesStep(),
          _buildFamilyMembersStep(),
          _buildReviewStep(),
        ],
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildFamilySizeAndBudgetStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Family Size & Budget',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about your family and monthly food budget',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        
        // Family Size
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How many people in your family?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _familySize > 1
                          ? () {
                              setState(() {
                                _familySize--;
                                _initializeFamilyMembers();
                              });
                            }
                          : null,
                    ),
                    Text(
                      '$_familySize',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Builder(
                      builder: (context) {
                        final maxMembers =
                            context.watch<SubscriptionProvider>().maxFamilyMembers;
                        return IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _familySize < maxMembers
                              ? () {
                                  setState(() {
                                    _familySize++;
                                    _initializeFamilyMembers();
                                  });
                                }
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Monthly Budget
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Food Budget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _budgetCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: CurrencyUtils.availableCurrencies.map((currency) {
                          final symbol = CurrencyUtils.getCurrencySymbolByCode(currency);
                          return DropdownMenuItem(
                            value: currency,
                            child: Text('$currency ($symbol)'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _budgetCurrency = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _budgetController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Monthly Budget',
                          prefixText: '${CurrencyUtils.getCurrencySymbolByCode(_budgetCurrency)} ',
                          hintText: 'Enter budget amount',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _budgetController.clear();
                              setState(() {
                                _monthlyBudget = 0;
                              });
                            },
                          ),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null && parsed >= 0) {
                            setState(() {
                              _monthlyBudget = parsed;
                            });
                          }
                        },
                        onSubmitted: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null && parsed > 0) {
                            setState(() {
                              _monthlyBudget = parsed.clamp(1000, 1000000);
                              _budgetController.text = _monthlyBudget.toStringAsFixed(0);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick budget selection buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickBudgetButton(10000),
                    _buildQuickBudgetButton(20000),
                    _buildQuickBudgetButton(30000),
                    _buildQuickBudgetButton(50000),
                    _buildQuickBudgetButton(75000),
                    _buildQuickBudgetButton(100000),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _monthlyBudget.clamp(5000, 100000),
                  min: 5000,
                  max: 100000,
                  divisions: 19,
                  label: '$_budgetCurrency ${_monthlyBudget.toStringAsFixed(0)}',
                  onChanged: (value) {
                    setState(() {
                      _monthlyBudget = value;
                      _budgetController.text = value.toStringAsFixed(0);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _familySize > 0
                            ? 'Approximately ${(_monthlyBudget / (_familySize * 30)).toStringAsFixed(0)} $_budgetCurrency per person per day'
                            : 'Set family size to calculate per person budget',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Budget Level
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Budget Focus',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Low', 'Medium', 'High'].map((level) {
                    return ChoiceChip(
                      label: Text(level),
                      selected: _budgetLevel == level,
                      onSelected: (selected) {
                        setState(() => _budgetLevel = level);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _budgetLevel == 'Low'
                      ? 'Focus on affordable, budget-friendly meals'
                      : _budgetLevel == 'Medium'
                          ? 'Balance cost and quality ingredients'
                          : 'Premium ingredients, variety, and dining out',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Cost Saving Preferences
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cost Saving Strategies',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _costSavingPreferences.map((pref) {
                    return FilterChip(
                      label: Text(pref),
                      selected: _sharedAllergies.contains(pref),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _sharedAllergies.add(pref);
                          } else {
                            _sharedAllergies.remove(pref);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedPreferencesStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Family Preferences',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Set preferences that apply to your whole family',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        
        // Meals Per Day
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meals Per Day',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [2, 3, 4, 5].map((meals) {
                    return ChoiceChip(
                      label: Text('$meals meals'),
                      selected: _mealsPerDay == meals,
                      onSelected: (selected) {
                        setState(() => _mealsPerDay = meals);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Preferred Cuisine
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Cuisine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _preferredCuisine,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _cuisines.map((cuisine) {
                    return DropdownMenuItem(
                      value: cuisine,
                      child: Text(cuisine),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _preferredCuisine = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Cooking Skill Level
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cooking Skill Level',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _cookingSkills.map((skill) {
                    return ChoiceChip(
                      label: Text(skill),
                      selected: _cookingSkillLevel == skill,
                      onSelected: (selected) {
                        setState(() => _cookingSkillLevel = skill);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Shared Allergies
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Family Allergies (if any)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select any allergies that affect anyone in the family',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonAllergies.map((allergy) {
                    return FilterChip(
                      label: Text(allergy),
                      selected: _sharedAllergies.contains(allergy),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _sharedAllergies.add(allergy);
                          } else {
                            _sharedAllergies.remove(allergy);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMembersStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Family Members',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Add details for each family member',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        ..._familyMembers.asMap().entries.map((entry) {
          final index = entry.key;
          final member = entry.value;
          return _buildMemberCard(index, member);
        }),
      ],
    );
  }

  Widget _buildMemberCard(int index, FamilyMember member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${member.age} years old • ${member.gender}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: member.name,
                  onChanged: (value) {
                    setState(() {
                      _familyMembers[index] = FamilyMember(
                        id: member.id,
                        name: value,
                        age: member.age,
                        gender: member.gender,
                        healthGoals: member.healthGoals,
                        diseases: member.diseases,
                        allergies: member.allergies,
                        preferredFlavor: member.preferredFlavor,
                        dietType: member.dietType,
                        activityLevel: member.activityLevel,
                        targetWeight: member.targetWeight,
                      );
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: member.age.toString(),
                        onChanged: (value) {
                          setState(() {
                            _familyMembers[index] = FamilyMember(
                              id: member.id,
                              name: member.name,
                              age: int.tryParse(value) ?? member.age,
                              gender: member.gender,
                              healthGoals: member.healthGoals,
                              diseases: member.diseases,
                              allergies: member.allergies,
                              preferredFlavor: member.preferredFlavor,
                              dietType: member.dietType,
                              activityLevel: member.activityLevel,
                              targetWeight: member.targetWeight,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: member.gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'Other'].map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _familyMembers[index] = FamilyMember(
                                id: member.id,
                                name: member.name,
                                age: member.age,
                                gender: value,
                                healthGoals: member.healthGoals,
                                diseases: member.diseases,
                                allergies: member.allergies,
                                preferredFlavor: member.preferredFlavor,
                                dietType: member.dietType,
                                activityLevel: member.activityLevel,
                                targetWeight: member.targetWeight,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Health Goals',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _healthGoals.map((goal) {
                    return FilterChip(
                      label: Text(goal),
                      selected: member.healthGoals.contains(goal),
                      onSelected: (selected) {
                        setState(() {
                          final goals = List<String>.from(member.healthGoals);
                          if (selected) {
                            goals.add(goal);
                          } else {
                            goals.remove(goal);
                          }
                          _familyMembers[index] = FamilyMember(
                            id: member.id,
                            name: member.name,
                            age: member.age,
                            gender: member.gender,
                            healthGoals: goals,
                            diseases: member.diseases,
                            allergies: member.allergies,
                            preferredFlavor: member.preferredFlavor,
                            dietType: member.dietType,
                            activityLevel: member.activityLevel,
                            targetWeight: member.targetWeight,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Health Conditions',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonDiseases.map((disease) {
                    return FilterChip(
                      label: Text(disease),
                      selected: member.diseases.contains(disease),
                      onSelected: (selected) {
                        setState(() {
                          final diseases = List<String>.from(member.diseases);
                          if (selected) {
                            diseases.add(disease);
                          } else {
                            diseases.remove(disease);
                          }
                          _familyMembers[index] = FamilyMember(
                            id: member.id,
                            name: member.name,
                            age: member.age,
                            gender: member.gender,
                            healthGoals: member.healthGoals,
                            diseases: diseases,
                            allergies: member.allergies,
                            preferredFlavor: member.preferredFlavor,
                            dietType: member.dietType,
                            activityLevel: member.activityLevel,
                            targetWeight: member.targetWeight,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: member.preferredFlavor,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Flavor',
                    border: OutlineInputBorder(),
                  ),
                  items: _flavors.map((flavor) {
                    return DropdownMenuItem(
                      value: flavor,
                      child: Text(flavor),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _familyMembers[index] = FamilyMember(
                          id: member.id,
                          name: member.name,
                          age: member.age,
                          gender: member.gender,
                          healthGoals: member.healthGoals,
                          diseases: member.diseases,
                          allergies: member.allergies,
                          preferredFlavor: value,
                          dietType: member.dietType,
                          activityLevel: member.activityLevel,
                          targetWeight: member.targetWeight,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: member.dietType,
                  decoration: const InputDecoration(
                    labelText: 'Diet Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _dietTypes.map((diet) {
                    return DropdownMenuItem(
                      value: diet,
                      child: Text(diet),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _familyMembers[index] = FamilyMember(
                          id: member.id,
                          name: member.name,
                          age: member.age,
                          gender: member.gender,
                          healthGoals: member.healthGoals,
                          diseases: member.diseases,
                          allergies: member.allergies,
                          preferredFlavor: member.preferredFlavor,
                          dietType: value,
                          activityLevel: member.activityLevel,
                          targetWeight: member.targetWeight,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: member.activityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    border: OutlineInputBorder(),
                  ),
                  items: _activityLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(level),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _familyMembers[index] = FamilyMember(
                          id: member.id,
                          name: member.name,
                          age: member.age,
                          gender: member.gender,
                          healthGoals: member.healthGoals,
                          diseases: member.diseases,
                          allergies: member.allergies,
                          preferredFlavor: member.preferredFlavor,
                          dietType: member.dietType,
                          activityLevel: value,
                          targetWeight: member.targetWeight,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Review & Confirm',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Review your family plan setup',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Family Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildReviewItem('Family Size', '$_familySize members'),
                _buildReviewItem('Monthly Budget', '$_budgetCurrency ${_monthlyBudget.toStringAsFixed(0)}'),
                _buildReviewItem('Budget Level', _budgetLevel),
                _buildReviewItem('Meals Per Day', '$_mealsPerDay meals'),
                _buildReviewItem('Preferred Cuisine', _preferredCuisine),
                _buildReviewItem('Cooking Skill', _cookingSkillLevel),
                if (_sharedAllergies.isNotEmpty)
                  _buildReviewItem('Family Allergies', _sharedAllergies.join(', ')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        const Text(
          'Family Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._familyMembers.map((member) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${member.age} years • ${member.gender}'),
                  if (member.healthGoals.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Goals: ${member.healthGoals.join(', ')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                  if (member.diseases.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Conditions: ${member.diseases.join(', ')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Flavor: ${member.preferredFlavor} • Diet: ${member.dietType}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        
        ElevatedButton.icon(
          onPressed: _saveFamilyPlan,
          icon: const Icon(Icons.check_circle),
          label: const Text('Complete Setup'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBudgetButton(double amount) {
    final isSelected = (_monthlyBudget - amount).abs() < 100;
    final formattedAmount = amount >= 1000 
        ? '${(amount / 1000).toStringAsFixed(0)}K'
        : amount.toStringAsFixed(0);
    
    return ActionChip(
      label: Text('$_budgetCurrency $formattedAmount'),
      backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : null,
      side: isSelected 
          ? BorderSide(color: Theme.of(context).primaryColor) 
          : const BorderSide(color: Colors.grey),
      onPressed: () {
        setState(() {
          _monthlyBudget = amount;
          _budgetController.text = amount.toStringAsFixed(0);
        });
      },
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage < 3
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: Text(_currentPage < 3 ? 'Next' : 'Review'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFamilyPlan() async {
    // Validate family members
    if (_familyMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one family member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate required fields for each family member
    for (final member in _familyMembers) {
      if (member.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter names for all family members'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final setup = FamilyPlanSetup(
      familySize: _familySize,
      members: _familyMembers,
      monthlyBudget: _monthlyBudget,
      budgetCurrency: _budgetCurrency,
      sharedAllergies: _sharedAllergies,
      preferredCuisine: _preferredCuisine,
      cookingSkillLevel: _cookingSkillLevel,
      mealsPerDay: _mealsPerDay,
    );

    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.user != null) {
      // Check subscription before saving
      final subProvider = context.read<SubscriptionProvider>();
      if (!subProvider.canAccessFamilyProfiles) {
        if (mounted) {
          FeatureRestrictionDialog.show(
            context,
            featureName: 'Family Meal Planning',
            featureDescription:
                'Premium supports up to 7 family members; Ultra supports up to 10.',
            icon: Icons.family_restroom_rounded,
          );
        }
        return;
      }

      if (_familySize > subProvider.maxFamilyMembers) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your plan allows up to ${subProvider.maxFamilyMembers} family members.',
              ),
            ),
          );
        }
        return;
      }

      try {
        // Save to Firestore
        await context.read<FamilyProfileProvider>().saveFamilyPlanSetup(
          authProvider.user!.uid,
          setup,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Family plan setup completed!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, setup);
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('permission') || errorMsg.contains('denied') || errorMsg.contains('unauthorized')) {
            FeatureRestrictionDialog.show(
              context,
              featureName: 'Family Meal Planning',
              featureDescription: 'Upgrade to the Family plan to save and manage family meal plans.',
              icon: Icons.family_restroom_rounded,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save family plan: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        debugPrint('Family plan save error: $e');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to save family plans'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _budgetController.dispose();
    super.dispose();
  }
}
