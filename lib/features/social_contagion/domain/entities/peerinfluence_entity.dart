import 'package:equatable/equatable.dart';

class PeerInfluenceEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const PeerInfluenceEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
