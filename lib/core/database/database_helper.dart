import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = "WelloaEnterprise.db";
  static const int _databaseVersion = 2;

  // Table Names
  static const String tableBioTwin = 'bio_twin';
  static const String tableHallmarkScores = 'hallmark_scores';
  static const String tableBioMarkers = 'bio_markers';
  static const String tableSimulations = 'simulations';

  static const String tableAegSynthesis = 'aeg_synthesis';
  static const String tableAegNodes = 'aeg_nodes';
  static const String tableAegEdges = 'aeg_edges';

  static const String tableFoodScans = 'food_scans';
  static const String tableFoodScanGuidance = 'food_scan_guidance';

  static const String tableProtocols = 'protocols';
  static const String tableSupplements = 'supplements';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseTables(db);
    await _createProtocolTables(db);
  }

  Future<void> _createBaseTables(Database db) async {
    // BioTwin Core Table
    await db.execute('''
      CREATE TABLE $tableBioTwin (
        id TEXT PRIMARY KEY,
        compiledAt TEXT NOT NULL,
        chronologicalAge REAL NOT NULL,
        biologicalAge REAL NOT NULL,
        ageGap REAL NOT NULL,
        reversalRateMonthsPerYear REAL NOT NULL,
        trajectory TEXT NOT NULL
      )
    ''');

    // Hallmark Scores Table
    await db.execute('''
      CREATE TABLE $tableHallmarkScores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bioTwinId TEXT NOT NULL,
        hallmarkName TEXT NOT NULL,
        score REAL NOT NULL,
        trend TEXT NOT NULL,
        FOREIGN KEY (bioTwinId) REFERENCES $tableBioTwin (id) ON DELETE CASCADE
      )
    ''');

    // Key BioMarkers Table
    await db.execute('''
      CREATE TABLE $tableBioMarkers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bioTwinId TEXT NOT NULL,
        name TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        optimalRange TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (bioTwinId) REFERENCES $tableBioTwin (id) ON DELETE CASCADE
      )
    ''');

    // Simulation Points Table
    await db.execute('''
      CREATE TABLE $tableSimulations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bioTwinId TEXT NOT NULL,
        monthOffset INTEGER NOT NULL,
        projectedBioAge REAL NOT NULL,
        FOREIGN KEY (bioTwinId) REFERENCES $tableBioTwin (id) ON DELETE CASCADE
      )
    ''');

    // AEG Synthesis Table
    await db.execute('''
      CREATE TABLE $tableAegSynthesis (
        id TEXT PRIMARY KEY,
        generatedAt TEXT NOT NULL,
        topPriorityAction TEXT NOT NULL,
        biologicalNetworkHealth REAL NOT NULL,
        overallOptimizationScore REAL NOT NULL,
        synthesisNarrative TEXT NOT NULL,
        criticalBottleneck TEXT NOT NULL
      )
    ''');

    // AEG Nodes Table
    await db.execute('''
      CREATE TABLE $tableAegNodes (
        id TEXT PRIMARY KEY,
        synthesisId TEXT NOT NULL,
        label TEXT NOT NULL,
        nodeType TEXT NOT NULL,
        currentValue REAL NOT NULL,
        optimalValue REAL NOT NULL,
        unit TEXT NOT NULL,
        status TEXT NOT NULL,
        impactScore REAL NOT NULL,
        FOREIGN KEY (synthesisId) REFERENCES $tableAegSynthesis (id) ON DELETE CASCADE
      )
    ''');

    // AEG Edges Table
    await db.execute('''
      CREATE TABLE $tableAegEdges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        synthesisId TEXT NOT NULL,
        fromNodeId TEXT NOT NULL,
        toNodeId TEXT NOT NULL,
        edgeType TEXT NOT NULL,
        strength REAL NOT NULL,
        latencyHours REAL NOT NULL,
        FOREIGN KEY (synthesisId) REFERENCES $tableAegSynthesis (id) ON DELETE CASCADE
      )
    ''');

    // Food Scans Table
    await db.execute('''
      CREATE TABLE $tableFoodScans (
        id TEXT PRIMARY KEY,
        analyzedAt TEXT NOT NULL,
        totalAgeScore REAL NOT NULL,
        polyphenolScore REAL NOT NULL,
        biologicalAgeCostMinutes REAL NOT NULL,
        metric1Label TEXT NOT NULL,
        metric1Value TEXT NOT NULL,
        metric2Label TEXT NOT NULL,
        metric2Value TEXT NOT NULL,
        aiQuestion TEXT NOT NULL,
        dailyGoal TEXT NOT NULL
      )
    ''');

    // Food Scan Guidance List
    await db.execute('''
      CREATE TABLE $tableFoodScanGuidance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanId TEXT NOT NULL,
        guidance TEXT NOT NULL,
        FOREIGN KEY (scanId) REFERENCES $tableFoodScans (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createProtocolTables(Database db) async {
    await db.execute('''
      CREATE TABLE $tableProtocols (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        objective TEXT NOT NULL,
        isCircadianSynced INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSupplements (
        id TEXT PRIMARY KEY,
        protocolId TEXT NOT NULL,
        name TEXT NOT NULL,
        dosage REAL NOT NULL,
        unit TEXT NOT NULL,
        timing TEXT NOT NULL,
        activeCompounds TEXT NOT NULL,
        requiresFat INTEGER NOT NULL,
        requiresFasting INTEGER NOT NULL,
        FOREIGN KEY (protocolId) REFERENCES $tableProtocols (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createProtocolTables(db);
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
