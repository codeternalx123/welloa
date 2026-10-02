import 'package:equatable/equatable.dart';

class MetaboliteEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const MetaboliteEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
