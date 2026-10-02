import 'package:equatable/equatable.dart';

class BacterialStrainEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const BacterialStrainEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
