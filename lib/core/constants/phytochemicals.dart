/// AEG Longevity Platform — Phytochemical Database
/// Maps key dietary phytochemicals to their hallmark-protective activities.
library phytochemicals;

/// Immutable model for a single bioactive phytochemical compound.
class PhytochemicalModel {
  const PhytochemicalModel({
    required this.name,
    required this.pigmentType,
    required this.colorDescription,
    required this.hallmarksProtected,
    required this.foodSources,
    required this.optimalIntakeMg,
    required this.counterAgeScore,
  });

  /// IUPAC or common chemical name
  final String name;

  /// Pigment class (e.g. Flavonoid, Carotenoid, Glucosinolate)
  final String pigmentType;

  /// Human-readable colour of the food indicator (for UI colour coding)
  final String colorDescription;

  /// Hallmark IDs that this phytochemical has clinical evidence of protecting
  final List<String> hallmarksProtected;

  /// Best dietary sources, ordered by concentration
  final List<String> foodSources;

  /// Evidence-based optimal daily intake in mg (approximate)
  final double optimalIntakeMg;

  /// AEG proprietary counter-age score (0–100)
  /// Higher = more multi-hallmark, bioavailable, and evidence-backed
  final int counterAgeScore;
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 Core Phytochemicals with scientific data
// ─────────────────────────────────────────────────────────────────────────────

const List<PhytochemicalModel> kPhytochemicals = [
  // 1 ─ Anthocyanins
  PhytochemicalModel(
    name: 'Anthocyanins',
    pigmentType: 'Flavonoid (Anthocyanidin glycosides)',
    colorDescription: 'Deep purple-blue-red (berries, red cabbage)',
    hallmarksProtected: [
      'genomic_instability',
      'telomere_attrition',
      'chronic_inflammation',
      'altered_intercellular_communication',
      'mitochondrial_dysfunction',
    ],
    foodSources: [
      'Wild blueberries (1 cup ≈ 400 mg)',
      'Blackberries (1 cup ≈ 350 mg)',
      'Black currants (1 cup ≈ 500 mg)',
      'Elderberries (100 g ≈ 450 mg)',
      'Red cabbage (100 g ≈ 180 mg)',
      'Purple sweet potato (100 g ≈ 900 mg)',
      'Açaí berry (100 g ≈ 320 mg)',
      'Chokeberries / aronia (100 g ≈ 1480 mg)',
    ],
    optimalIntakeMg: 300.0,
    counterAgeScore: 91,
  ),

  // 2 ─ Glucosinolates
  PhytochemicalModel(
    name: 'Glucosinolates',
    pigmentType: 'Sulfur-containing glycosides',
    colorDescription: 'Green / white (cruciferous vegetables)',
    hallmarksProtected: [
      'genomic_instability',
      'epigenetic_alterations',
      'cellular_senescence',
      'chronic_inflammation',
      'dysbiosis',
    ],
    foodSources: [
      'Broccoli sprouts (100 g ≈ 800 mg glucoraphanin)',
      'Brussels sprouts (100 g ≈ 237 mg)',
      'Kale (100 g ≈ 110 mg)',
      'Cabbage (100 g ≈ 101 mg)',
      'Watercress (100 g ≈ 95 mg)',
      'Cauliflower (100 g ≈ 62 mg)',
      'Bok choy (100 g ≈ 70 mg)',
      'Kohlrabi (100 g ≈ 90 mg)',
    ],
    optimalIntakeMg: 200.0,
    counterAgeScore: 88,
  ),

  // 3 ─ Lycopene
  PhytochemicalModel(
    name: 'Lycopene',
    pigmentType: 'Carotenoid (acyclic)',
    colorDescription: 'Vivid red (tomatoes, watermelon)',
    hallmarksProtected: [
      'genomic_instability',
      'telomere_attrition',
      'chronic_inflammation',
      'mitochondrial_dysfunction',
    ],
    foodSources: [
      'Cooked tomatoes — paste 100 g ≈ 29 mg (cooking ↑ bioavailability)',
      'Tomato sauce (100 g ≈ 15 mg)',
      'Watermelon (100 g ≈ 4.5 mg)',
      'Pink grapefruit (100 g ≈ 1.5 mg)',
      'Guava (100 g ≈ 5.4 mg)',
      'Papaya (100 g ≈ 1.8 mg)',
      'Red bell pepper (100 g ≈ 0.5 mg)',
      'Rosehip (100 g ≈ 1.1 mg)',
    ],
    optimalIntakeMg: 15.0,
    counterAgeScore: 79,
  ),

  // 4 ─ Quercetin
  PhytochemicalModel(
    name: 'Quercetin',
    pigmentType: 'Flavonol',
    colorDescription: 'Yellow-green (onions, capers)',
    hallmarksProtected: [
      'cellular_senescence',
      'chronic_inflammation',
      'epigenetic_alterations',
      'mitochondrial_dysfunction',
      'disabled_macroautophagy',
    ],
    foodSources: [
      'Capers, raw (100 g ≈ 233 mg)',
      'Lovage (100 g ≈ 170 mg)',
      'Dill weed (100 g ≈ 55 mg)',
      'Red onion (100 g ≈ 32 mg)',
      'Kale (100 g ≈ 23 mg)',
      'Broccoli (100 g ≈ 3 mg)',
      'Apples with skin (100 g ≈ 4.4 mg)',
      'Green tea (1 cup ≈ 2.5 mg)',
    ],
    optimalIntakeMg: 500.0,
    counterAgeScore: 87,
  ),

  // 5 ─ Resveratrol
  PhytochemicalModel(
    name: 'Resveratrol',
    pigmentType: 'Stilbenoid (polyphenol)',
    colorDescription: 'Pale amber (red wine, grape skin)',
    hallmarksProtected: [
      'epigenetic_alterations',
      'deregulated_nutrient_sensing',
      'cellular_senescence',
      'telomere_attrition',
      'mitochondrial_dysfunction',
      'disabled_macroautophagy',
    ],
    foodSources: [
      'Muscadine grapes (100 g ≈ 1.5 mg — highest natural source)',
      'Red wine (150 ml ≈ 0.3–1.9 mg)',
      'Peanuts, boiled (100 g ≈ 0.3 mg)',
      'Blueberries (100 g ≈ 0.04 mg)',
      'Cranberries (100 g ≈ 0.02 mg)',
      'Dark chocolate (100 g ≈ 0.01 mg)',
      'Pistachio (100 g ≈ 0.1 mg)',
      'Japanese knotweed root (supplement — highest extracted form)',
    ],
    optimalIntakeMg: 500.0,
    counterAgeScore: 82,
  ),

  // 6 ─ Curcumin
  PhytochemicalModel(
    name: 'Curcumin',
    pigmentType: 'Curcuminoid (diarylheptanoid)',
    colorDescription: 'Vivid golden-yellow (turmeric root)',
    hallmarksProtected: [
      'genomic_instability',
      'epigenetic_alterations',
      'loss_of_proteostasis',
      'chronic_inflammation',
      'cellular_senescence',
      'altered_intercellular_communication',
    ],
    foodSources: [
      'Turmeric powder (100 g ≈ 3400 mg curcumin)',
      'Fresh turmeric root (100 g ≈ 1700 mg)',
      'Curry powder (100 g ≈ 1700 mg)',
      'Golden milk (1 cup with 1 tsp turmeric ≈ 170 mg)',
      'Mango ginger / Curcuma amada (100 g ≈ 800 mg)',
    ],
    optimalIntakeMg: 1000.0,
    counterAgeScore: 90,
  ),

  // 7 ─ EGCG (Epigallocatechin gallate)
  PhytochemicalModel(
    name: 'EGCG',
    pigmentType: 'Catechin (Flavan-3-ol)',
    colorDescription: 'Pale green (green tea, matcha)',
    hallmarksProtected: [
      'genomic_instability',
      'epigenetic_alterations',
      'loss_of_proteostasis',
      'deregulated_nutrient_sensing',
      'stem_cell_exhaustion',
      'chronic_inflammation',
    ],
    foodSources: [
      'Matcha (1 tsp ≈ 137 mg EGCG)',
      'Japanese sencha (1 cup ≈ 50–100 mg)',
      'Gyokuro (1 cup ≈ 50–80 mg)',
      'Dragonwell / Longjing tea (1 cup ≈ 40–80 mg)',
      'White tea (1 cup ≈ 15–30 mg)',
      'Carob flour (100 g ≈ low but diverse catechins)',
      'Dark chocolate (100 g ≈ 12 mg catechins)',
      'Peaches (100 g ≈ 1 mg)',
    ],
    optimalIntakeMg: 400.0,
    counterAgeScore: 89,
  ),

  // 8 ─ Sulforaphane
  PhytochemicalModel(
    name: 'Sulforaphane',
    pigmentType: 'Isothiocyanate (glucosinolate metabolite)',
    colorDescription: 'Green (broccoli sprouts — highest source)',
    hallmarksProtected: [
      'genomic_instability',
      'epigenetic_alterations',
      'loss_of_proteostasis',
      'cellular_senescence',
      'chronic_inflammation',
      'stem_cell_exhaustion',
    ],
    foodSources: [
      'Broccoli sprouts (100 g ≈ 73 mg — 50× mature broccoli)',
      'Radish sprouts (100 g ≈ 25 mg)',
      'Broccoli, raw (100 g ≈ 2.4 mg active after myrosinase)',
      'Cauliflower, raw (100 g ≈ 1.1 mg)',
      'Cabbage, raw (100 g ≈ 0.9 mg)',
      'Kohlrabi (100 g ≈ 0.8 mg)',
      'Bok choy (100 g ≈ 0.7 mg)',
      'Brussels sprouts, raw (100 g ≈ 1.3 mg)',
    ],
    optimalIntakeMg: 50.0,
    counterAgeScore: 94,
  ),

  // 9 ─ Chlorogenic Acid
  PhytochemicalModel(
    name: 'Chlorogenic Acid',
    pigmentType: 'Hydroxycinnamic acid (polyphenol ester)',
    colorDescription: 'Tan-brown (coffee, green coffee bean)',
    hallmarksProtected: [
      'deregulated_nutrient_sensing',
      'chronic_inflammation',
      'mitochondrial_dysfunction',
      'dysbiosis',
    ],
    foodSources: [
      'Green coffee bean extract (100 g ≈ 6–12 g)',
      'Roasted coffee (1 cup ≈ 200–550 mg)',
      'Sunflower seeds (100 g ≈ 2000 mg)',
      'Artichokes (100 g ≈ 1200 mg)',
      'Potatoes (100 g ≈ 50 mg raw, reduced by cooking)',
      'Blueberries (100 g ≈ 85 mg)',
      'Eggplant / aubergine (100 g ≈ 65 mg)',
      'Apples (100 g ≈ 40 mg)',
    ],
    optimalIntakeMg: 600.0,
    counterAgeScore: 76,
  ),

  // 10 ─ Beta-Carotene
  PhytochemicalModel(
    name: 'Beta-Carotene',
    pigmentType: 'Carotenoid (provitamin A)',
    colorDescription: 'Orange-yellow (carrots, sweet potato)',
    hallmarksProtected: [
      'genomic_instability',
      'chronic_inflammation',
      'stem_cell_exhaustion',
      'altered_intercellular_communication',
    ],
    foodSources: [
      'Sweet potato, baked (100 g ≈ 8.5 mg)',
      'Carrots, raw (100 g ≈ 8.3 mg)',
      'Butternut squash (100 g ≈ 4.5 mg)',
      'Kale (100 g ≈ 9.2 mg)',
      'Spinach, raw (100 g ≈ 5.6 mg)',
      'Cantaloupe melon (100 g ≈ 2.0 mg)',
      'Apricots (100 g ≈ 1.6 mg)',
      'Red bell pepper (100 g ≈ 2.1 mg)',
    ],
    optimalIntakeMg: 6.0,
    counterAgeScore: 72,
  ),
];
