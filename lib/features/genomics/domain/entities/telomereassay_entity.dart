import 'package:equatable/equatable.dart';

class TelomereAssayEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const TelomereAssayEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
