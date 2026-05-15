import 'package:intl/intl.dart';

class RideGroup {
  final String id;
  final String name;
  final String route;
  final DateTime date;
  final int maxRiders;
  final int memberCount;
  final String leaderName;
  final String rideCommunity;
  final String rideType;
  final String difficulty;
  final String duration;
  final String routeImageUrl;

  RideGroup({
    required this.id,
    required this.name,
    required this.route,
    required this.date,
    required this.maxRiders,
    required this.memberCount,
    required this.leaderName,
    this.rideCommunity = 'motorcycle',
    required this.rideType,
    required this.difficulty,
    required this.duration,
    required this.routeImageUrl,
  });

  String get formattedDate => DateFormat('EEE, MMM d - h:mm a').format(date);

  bool get isBicycle => rideCommunity == 'bicycle';

  String get communityLabel => isBicycle ? 'Bicycle' : 'Motorcycle';
}
