import 'package:equatable/equatable.dart';

class AminoAcidProfileEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const AminoAcidProfileEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
