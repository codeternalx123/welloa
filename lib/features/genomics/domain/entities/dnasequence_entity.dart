import 'package:equatable/equatable.dart';

class DnaSequenceEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const DnaSequenceEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
