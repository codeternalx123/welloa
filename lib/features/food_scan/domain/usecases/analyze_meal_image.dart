import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/phytochemical_analysis.dart';
import '../repositories/food_scan_repository.dart';

class AnalyzeMealImageUseCase {
  final FoodScanRepository repository;

  AnalyzeMealImageUseCase(this.repository);

  Future<Either<Failure, PhytochemicalAnalysis>> execute(String base64Image) async {
    if (base64Image.isEmpty) {
      return const Left(CacheFailure('Image data cannot be empty'));
    }
    return await repository.analyzeMealImage(base64Image);
  }
}
