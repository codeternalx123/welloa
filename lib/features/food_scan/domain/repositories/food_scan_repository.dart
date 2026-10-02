import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/phytochemical_analysis.dart';

abstract class FoodScanRepository {
  Future<Either<Failure, PhytochemicalAnalysis>> analyzeMealImage(String base64Image);
  Future<Either<Failure, List<PhytochemicalAnalysis>>> getScanHistory();
}
