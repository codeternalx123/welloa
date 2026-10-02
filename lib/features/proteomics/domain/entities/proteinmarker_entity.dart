import 'package:equatable/equatable.dart';

class ProteinMarkerEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const ProteinMarkerEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
