import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../../features/protocols/domain/models/protocol.dart';
import '../../../features/protocols/domain/models/supplement.dart';

class SupplementDao {
  final DatabaseHelper dbHelper;

  SupplementDao({required this.dbHelper});

  Future<void> insertProtocol(LongevityProtocol protocol) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        DatabaseHelper.tableProtocols,
        {
          'id': protocol.id,
          'name': protocol.name,
          'objective': protocol.objective,
          'isCircadianSynced': protocol.isCircadianSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Delete existing supplements for this protocol to avoid orphans on replace
      await txn.delete(
        DatabaseHelper.tableSupplements,
        where: 'protocolId = ?',
        whereArgs: [protocol.id],
      );

      for (var supp in protocol.supplements) {
        await txn.insert(
          DatabaseHelper.tableSupplements,
          {
            'id': supp.id,
            'protocolId': protocol.id,
            'name': supp.name,
            'dosage': supp.dosage,
            'unit': supp.unit,
            'timing': supp.timing.name,
            'activeCompounds': jsonEncode(supp.activeCompounds),
            'requiresFat': supp.requiresFat ? 1 : 0,
            'requiresFasting': supp.requiresFasting ? 1 : 0,
          },
        );
      }
    });
  }

  Future<LongevityProtocol?> getProtocol(String id) async {
    final db = await dbHelper.database;

    final protocolMaps = await db.query(
      DatabaseHelper.tableProtocols,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (protocolMaps.isEmpty) return null;

    final pMap = protocolMaps.first;

    final suppMaps = await db.query(
      DatabaseHelper.tableSupplements,
      where: 'protocolId = ?',
      whereArgs: [id],
    );

    final supplements = suppMaps.map((sMap) {
      return Supplement(
        id: sMap['id'] as String,
        name: sMap['name'] as String,
        dosage: sMap['dosage'] as double,
        unit: sMap['unit'] as String,
        timing: SupplementTiming.values.firstWhere(
          (e) => e.name == sMap['timing'],
          orElse: () => SupplementTiming.anytime,
        ),
        activeCompounds: List<String>.from(jsonDecode(sMap['activeCompounds'] as String)),
        requiresFat: (sMap['requiresFat'] as int) == 1,
        requiresFasting: (sMap['requiresFasting'] as int) == 1,
      );
    }).toList();

    return LongevityProtocol(
      id: pMap['id'] as String,
      name: pMap['name'] as String,
      objective: pMap['objective'] as String,
      isCircadianSynced: (pMap['isCircadianSynced'] as int) == 1,
      supplements: supplements,
    );
  }
}
