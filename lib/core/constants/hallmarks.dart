/// AEG Longevity Platform — The 12 Hallmarks of Aging
/// Based on López-Otín et al. (2023), Cell 186(2):243-278.
/// Each hallmark includes actionable nutritional and lifestyle data.
library hallmarks;

/// Immutable data model for a single Hallmark of Aging.
class HallmarkModel {
  const HallmarkModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.colorHex,
    required this.foodSources,
    required this.damagingFactors,
  });

  /// Unique snake_case identifier (e.g. 'genomic_instability')
  final String id;

  /// Human-readable full name
  final String name;

  /// One-sentence mechanistic description (≤ 20 words)
  final String shortDescription;

  /// Hex color code (without #) for UI theming
  final String colorHex;

  /// Foods / compounds that protect or repair this hallmark
  final List<String> foodSources;

  /// Lifestyle or environmental factors that damage this hallmark
  final List<String> damagingFactors;
}

// ─────────────────────────────────────────────────────────────────────────────
// All 12 Hallmarks with scientifically grounded content
// ─────────────────────────────────────────────────────────────────────────────

const List<HallmarkModel> kHallmarks = [
  // 1 ─ Genomic Instability
  HallmarkModel(
    id: 'genomic_instability',
    name: 'Genomic Instability',
    shortDescription:
        'Accumulation of DNA damage from endogenous and exogenous sources '
        'overwhelms repair capacity, causing mutations and chromosomal aberrations.',
    colorHex: '3B82F6',
    foodSources: [
      'Broccoli sprouts (sulforaphane — NRF2 activator)',
      'Blueberries (anthocyanins — antioxidant protection)',
      'Brazil nuts (selenium — glutathione peroxidase cofactor)',
      'Salmon (omega-3 — anti-inflammatory, DNA protection)',
      'Green tea (EGCG — topoisomerase inhibitor, antioxidant)',
      'Dark leafy greens (folate — nucleotide synthesis)',
      'Turmeric (curcumin — DNA repair upregulation)',
      'Pomegranate (ellagic acid — DNA strand break protection)',
    ],
    damagingFactors: [
      'UV radiation (direct DNA strand breaks)',
      'Cigarette smoke (oxidative DNA damage, adduct formation)',
      'Alcohol consumption (acetaldehyde — DNA crosslinks)',
      'Processed meats (nitrosamines — DNA alkylation)',
      'Ionising radiation (double-strand breaks)',
      'Chronic psychological stress (cortisol — impairs DNA repair)',
      'Air pollution / particulates (oxidative DNA damage)',
      'Folate / B12 deficiency (uracil misincorporation)',
    ],
  ),

  // 2 ─ Telomere Attrition
  HallmarkModel(
    id: 'telomere_attrition',
    name: 'Telomere Attrition',
    shortDescription:
        'Progressive shortening of telomeric caps with each cell division '
        'eventually triggers senescence or apoptosis.',
    colorHex: '14B8A6',
    foodSources: [
      'Astragalus root (cycloastragenol — telomerase activator)',
      'Olive oil (oleic acid — telomere length preservation)',
      'Legumes (folate — telomere maintenance)',
      'Nuts and seeds (vitamin E — oxidative protection of telomeres)',
      'Coffee (polyphenols — telomere length association)',
      'Fatty fish (omega-3 — leukocyte telomere length)',
      'Mushrooms (ergothioneine — telomere-protective antioxidant)',
      'Berries (resveratrol precursors — SIRT1 → telomere stability)',
    ],
    damagingFactors: [
      'Sedentary lifestyle (shorter leukocyte telomeres)',
      'Psychological stress (telomerase suppression via cortisol)',
      'Obesity (adipokine-driven telomere erosion)',
      'Smoking (oxidative telomere damage, 5× faster attrition)',
      'Ultra-processed food diet (systemic inflammation)',
      'Sleep deprivation (oxidative stress → telomere shortening)',
      'Alcohol (direct telomere toxicity)',
      'Social isolation (chronic stress HPA axis activation)',
    ],
  ),

  // 3 ─ Epigenetic Alterations
  HallmarkModel(
    id: 'epigenetic_alterations',
    name: 'Epigenetic Alterations',
    shortDescription:
        'Age-related drift in DNA methylation, histone modification, and '
        'chromatin remodelling disrupts gene expression patterns.',
    colorHex: '6366F1',
    foodSources: [
      'Broccoli (sulforaphane — HDAC inhibitor, epigenetic reprogramming)',
      'Garlic (allyl compounds — DNA methylation regulation)',
      'Green tea (EGCG — DNMT inhibitor)',
      'Turmeric (curcumin — histone acetyltransferase modulation)',
      'Soy (isoflavones — DNMT3 modulation)',
      'Resveratrol sources (SIRT1 deacetylase activation)',
      'Folate-rich foods (methyl donor for methylation)',
      'Beets (betaine — SAM biosynthesis, methylation support)',
    ],
    damagingFactors: [
      'Environmental toxins (BPA, heavy metals — aberrant methylation)',
      'High-fat / high-sugar diet (metabolic epigenome disruption)',
      'Sedentary behaviour (hypermethylation of exercise-responsive genes)',
      'Sleep disruption (circadian epigenome dysregulation)',
      'Alcohol (global DNA hypomethylation)',
      'Smoking (extensive CpG island methylation changes)',
      'Chronic stress (glucocorticoid receptor methylation)',
      'Ageing itself (epigenetic drift — Horvath clock acceleration)',
    ],
  ),

  // 4 ─ Loss of Proteostasis
  HallmarkModel(
    id: 'loss_of_proteostasis',
    name: 'Loss of Proteostasis',
    shortDescription:
        'Decline in protein quality-control networks leads to accumulation '
        'of misfolded and aggregated proteins.',
    colorHex: 'F59E0B',
    foodSources: [
      'Fasting / caloric restriction (autophagy upregulation)',
      'Spermidine-rich foods — wheat germ, aged cheese (autophagy induction)',
      'Ginger (gingerols — HSP chaperone induction)',
      'Curcumin (proteasome activation, aggregate disaggregation)',
      'Resveratrol (SIRT1 → deacetylation of autophagy proteins)',
      'Green tea (EGCG — prevents amyloid aggregation)',
      'Cruciferous vegetables (NRF2 → proteasome gene expression)',
      'Pomegranate (urolithins — mitophagy and proteostasis support)',
    ],
    damagingFactors: [
      'Chronic high-protein intake without cycling (mTOR overactivation)',
      'Alcohol (protein aggregation, ER stress)',
      'Heavy metals (cadmium, mercury — proteasome inhibition)',
      'Sedentary lifestyle (reduced heat shock response)',
      'Hyperglycaemia (glycation of proteins — AGEs formation)',
      'Sleep deprivation (glymphatic clearance failure)',
      'Pesticide exposure (proteasome dysfunction)',
      'Chronic inflammation (cytokine-driven proteasome impairment)',
    ],
  ),

  // 5 ─ Deregulated Nutrient Sensing
  HallmarkModel(
    id: 'deregulated_nutrient_sensing',
    name: 'Deregulated Nutrient Sensing',
    shortDescription:
        'Loss of optimal mTOR, AMPK, IGF-1, and sirtuin pathway calibration '
        'disrupts cellular anabolism/catabolism balance.',
    colorHex: '10B981',
    foodSources: [
      'Caloric restriction mimetics — resveratrol, berberine',
      'Legumes (slow carbs — AMPK activation)',
      'Intermittent fasting protocol (mTOR pulsing)',
      'Rapamycin-mimicking compounds (allicin in garlic)',
      'Metformin-like compounds (bitter melon extract)',
      'Green tea (EGCG — AMPK phosphorylation)',
      'Extra-virgin olive oil (oleocanthal — IGF-1 pathway)',
      'Walnuts (alpha-linolenic acid — insulin sensitivity)',
    ],
    damagingFactors: [
      'Constant snacking / grazing (no mTOR cycling)',
      'Excess refined carbohydrates (chronic insulin spike)',
      'Sedentary lifestyle (AMPK underactivation)',
      'Obesity (IGF-1 and insulin resistance)',
      'Growth hormone supplementation abuse',
      'Alcohol (mTOR dysregulation)',
      'High dairy / branched-chain amino acids (mTORC1 overactivation)',
      'Circadian rhythm disruption (clock-nutrient sensing crosstalk)',
    ],
  ),

  // 6 ─ Mitochondrial Dysfunction
  HallmarkModel(
    id: 'mitochondrial_dysfunction',
    name: 'Mitochondrial Dysfunction',
    shortDescription:
        'Decline in mitochondrial biogenesis, dynamics, and electron transport '
        'chain efficiency increases ROS and reduces ATP output.',
    colorHex: 'F97316',
    foodSources: [
      'CoQ10 sources — sardines, organ meats, broccoli',
      'Magnesium-rich foods — pumpkin seeds, dark chocolate (ATP synthesis)',
      'PQQ sources — kiwi, parsley, green tea (mitogenesis)',
      'NAD+ precursors — niacin, NMN, NR from avocado, edamame',
      'L-carnitine — red meat in moderation, tempeh',
      'Alpha-lipoic acid — spinach, peas, liver',
      'Berberine (AMPK → PGC-1α → mitochondrial biogenesis)',
      'Urolithins from pomegranate (mitophagy — quality control)',
    ],
    damagingFactors: [
      'Sedentary lifestyle (mitochondrial atrophy)',
      'Excess alcohol (complex I inhibition, mtDNA damage)',
      'Statin drugs (CoQ10 depletion — clinical concern)',
      'Smoking (cytochrome c oxidase inhibition)',
      'Sleep deprivation (mitochondrial fragmentation)',
      'Hyperglycaemia (ROS overproduction)',
      'Environmental toxins — pesticides, heavy metals',
      'Psychological stress (adrenaline → mitochondrial ROS)',
    ],
  ),

  // 7 ─ Cellular Senescence
  HallmarkModel(
    id: 'cellular_senescence',
    name: 'Cellular Senescence',
    shortDescription:
        'Accumulation of growth-arrested cells secreting pro-inflammatory '
        'SASP factors drives tissue dysfunction.',
    colorHex: '8B5CF6',
    foodSources: [
      'Quercetin — capers, red onion, kale (senolytic activity)',
      'Fisetin — strawberries, apples, persimmon (potent senolytic)',
      'Dasatinib-mimicking compounds — luteolin in celery',
      'Curcumin (p21 / p16 pathway modulation)',
      'Resveratrol (SIRT1 — anti-SASP signalling)',
      'Spermidine — wheat germ, natto (autophagy → senescence clearance)',
      'Navitoclax-analogous polyphenols — apigenin in parsley',
      'Piperlongumine analogs — black pepper (senolytic activity)',
    ],
    damagingFactors: [
      'Oncogenic stress (RAS mutations — OIS induction)',
      'Genotoxic stress (DNA damage — DDR senescence)',
      'Chronic inflammation (SASP amplification loop)',
      'Obesity (adipose tissue senescent cell accumulation)',
      'Alcohol (p53 pathway activation)',
      'Ionising radiation (radiation-induced senescence)',
      'Chemotherapy residue (therapy-induced senescence)',
      'Smoking (oxidative senescence induction)',
    ],
  ),

  // 8 ─ Stem Cell Exhaustion
  HallmarkModel(
    id: 'stem_cell_exhaustion',
    name: 'Stem Cell Exhaustion',
    shortDescription:
        'Depletion of tissue-resident stem cell pools impairs regenerative '
        'capacity across organ systems.',
    colorHex: 'EC4899',
    foodSources: [
      'Blueberries (pterostilbene — HSC rejuvenation)',
      'Astragalus (polysaccharides — haematopoietic stem cell support)',
      'Goji berries (zeaxanthin — retinal stem cell protection)',
      'Green tea (EGCG — neural stem cell proliferation)',
      'Sulforaphane — intestinal stem cell niche maintenance',
      'Vitamins D + K2 (mesenchymal stem cell differentiation)',
      'Omega-3 fatty acids (muscle satellite cell activation)',
      'NAD+ precursors (muscle stem cell rejuvenation via SIRT1)',
    ],
    damagingFactors: [
      'Ageing (intrinsic stem cell epigenetic ageing)',
      'Chronic inflammation (cytokine-driven stem cell quiescence)',
      'Alcohol (haematopoietic and hepatic stem cell toxicity)',
      'Chemotherapy (direct stem cell DNA damage)',
      'Sedentary lifestyle (muscle satellite cell atrophy)',
      'Obesity (adipose niche disruption of stem cells)',
      'Radiation exposure (bone marrow stem cell destruction)',
      'Hyperglycaemia (impaired MSC osteogenesis)',
    ],
  ),

  // 9 ─ Altered Intercellular Communication
  HallmarkModel(
    id: 'altered_intercellular_communication',
    name: 'Altered Intercellular Communication',
    shortDescription:
        'Age-related changes in endocrine, paracrine, and neural signalling '
        'degrade systemic coordination between tissues.',
    colorHex: '00F5FF',
    foodSources: [
      'Omega-3s (anti-inflammatory eicosanoid precursors)',
      'Curcumin (NF-κB inhibition — systemic cytokine reduction)',
      'Ginger (modulates TGF-β and exosome content)',
      'Green tea (EGCG — gap junction communication support)',
      'Extra-virgin olive oil (oleocanthal — IL-6, TNF-α inhibition)',
      'Dark chocolate (flavanols — endothelial signalling)',
      'Probiotics (gut-brain axis communication)',
      'Fermented foods (postbiotic signalling molecules)',
    ],
    damagingFactors: [
      'Inflammaging (chronic low-grade systemic inflammation)',
      'Sedentary lifestyle (myokine communication loss)',
      'Obesity (adipokine dysregulation — leptin resistance)',
      'Dysbiosis (disrupted gut-organ signalling)',
      'Sleep deprivation (hormonal rhythm disruption)',
      'Alcohol (neural and hormonal signal disruption)',
      'Smoking (endothelial signalling dysfunction)',
      'Social isolation (neuroendocrine communication decay)',
    ],
  ),

  // 10 ─ Disabled Macroautophagy
  HallmarkModel(
    id: 'disabled_macroautophagy',
    name: 'Disabled Macroautophagy',
    shortDescription:
        'Age-related decline in autophagy flux impairs cellular recycling of '
        'damaged organelles and protein aggregates.',
    colorHex: '84CC16',
    foodSources: [
      'Spermidine — wheat germ, aged cheese, mushrooms (direct autophagy inducer)',
      'Fasting (most potent physiological autophagy trigger)',
      'Resveratrol (SIRT1 → FOXO3 → Beclin-1 upregulation)',
      'Berberine (AMPK → ULK1 → autophagy initiation)',
      'Trehalose — rare in food; honey in trace amounts',
      'Urolithins — pomegranate → gut metabolites (mitophagy)',
      'Curcumin (mTOR inhibition → autophagy derepression)',
      'Lithium trace — mineral water (IMPase inhibition → autophagy)',
    ],
    damagingFactors: [
      'Constant caloric surplus (mTORC1 over-activation)',
      'Sedentary lifestyle (AMPK underactivation)',
      'High-sugar diet (mTOR → autophagy suppression)',
      'Alcohol (autophagosome-lysosome fusion block)',
      'Rapamycin-inhibiting environments (high amino acids)',
      'Sleep deprivation (circadian autophagy disruption)',
      'Environmental toxins (lysosomal membrane permeabilisation)',
      'Ageing itself (ATG gene expression decline)',
    ],
  ),

  // 11 ─ Chronic Inflammation (Inflammaging)
  HallmarkModel(
    id: 'chronic_inflammation',
    name: 'Chronic Inflammation',
    shortDescription:
        'Sterile, low-grade systemic inflammation driven by senescent cells, '
        'gut dysbiosis, and innate immune activation accelerates multi-organ ageing.',
    colorHex: 'EF4444',
    foodSources: [
      'Extra-virgin olive oil (oleocanthal — COX-1/2 inhibition)',
      'Fatty fish (EPA/DHA — resolvins, protectins)',
      'Turmeric + black pepper (curcumin — NF-κB inhibition)',
      'Tart cherries (anthocyanins — IL-6, CRP reduction)',
      'Walnuts (ALA → anti-inflammatory eicosanoids)',
      'Ginger (gingerol — PGE2 inhibition)',
      'Leafy greens (vitamin K — NF-κB modulation)',
      'Fermented foods (short-chain fatty acids — Treg induction)',
    ],
    damagingFactors: [
      'Ultra-processed food (AGEs, saturated fat — TLR4 activation)',
      'Sedentary lifestyle (lack of anti-inflammatory myokines)',
      'Obesity (visceral adipose — TNF-α, IL-6 secretion)',
      'Dysbiosis (LPS translocation — endotoxemia)',
      'Sleep deprivation (NF-κB and IL-6 elevation)',
      'Chronic psychological stress (sympathetic → NF-κB)',
      'Smoking (direct airway and systemic inflammatory activation)',
      'Alcohol (gut permeability → LPS → TLR4 → cytokines)',
    ],
  ),

  // 12 ─ Dysbiosis
  HallmarkModel(
    id: 'dysbiosis',
    name: 'Dysbiosis',
    shortDescription:
        'Age-related decline in gut microbiome diversity and increase of '
        'pro-inflammatory taxa impairs immune and metabolic homeostasis.',
    colorHex: 'D97706',
    foodSources: [
      'Fermented foods — kimchi, kefir, sauerkraut, miso (probiotic diversity)',
      'Prebiotic fibre — Jerusalem artichoke, chicory, leeks (Bifidobacterium feeding)',
      'Polyphenol-rich foods — berries, dark chocolate (microbiome diversity)',
      'Resistant starch — cooled potato, green banana (butyrate production)',
      'Pomegranate (urolithin-producing Akkermansia enrichment)',
      'Cruciferous vegetables (glucosinolates → indoles → AhR signalling)',
      'Legumes (diverse fibre → SCFA diversity)',
      'Whole grains (arabinoxylan — Lactobacillus / Bifidobacterium enrichment)',
    ],
    damagingFactors: [
      'Antibiotic overuse (collateral damage to commensal bacteria)',
      'Ultra-processed food (emulsifiers, artificial sweeteners)',
      'Low-fibre diet (microbiome starvation)',
      'Alcohol (dysbiosis, intestinal permeability)',
      'Chronic stress (cortisol → microbiome composition shift)',
      'Proton pump inhibitors (gastric pH change → SIBO)',
      'NSAIDs (gut mucosal damage → permeability)',
      'Sedentary lifestyle (reduced microbiome diversity)',
    ],
  ),
];
