import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ride_group_model.dart';
import '../../services/analytics_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/live_ride_service.dart';
import '../../services/pioneer_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/toast_widget.dart';
import '../live_ride/live_ride_navigation.dart';
import './widgets/create_group_modal_widget.dart';
import './widgets/group_card_widget.dart';
import './widgets/premium_gate_widget.dart';

class RideGroupsScreen extends StatefulWidget {
  const RideGroupsScreen({super.key});

  @override
  State<RideGroupsScreen> createState() => _RideGroupsScreenState();
}

class _RideGroupsScreenState extends State<RideGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<RideGroup> _myGroups = [];
  final List<RideGroup> _invitations = [];
  final Map<String, bool> _imHomeStatus = {};
  final Set<String> _selectedRideIds = {};

  bool _isLoading = true;
  bool _cleanupMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    PremiumService().addListener(_handlePremiumChanged);
    _loadGroups();
  }

  @override
  void dispose() {
    PremiumService().removeListener(_handlePremiumChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handlePremiumChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool _isPastRide(RideGroup group) {
    return group.date.isBefore(DateTime.now());
  }

  bool _canDeleteRide(RideGroup group) {
    return group.leaderName == 'You';
  }

  void _toggleCleanupMode() {
    setState(() {
      _cleanupMode = !_cleanupMode;
      _selectedRideIds.clear();
    });
  }

  void _toggleRideSelection(RideGroup group) {
    if (!_canDeleteRide(group)) return;

    setState(() {
      if (_selectedRideIds.contains(group.id)) {
        _selectedRideIds.remove(group.id);
      } else {
        _selectedRideIds.add(group.id);
      }
    });
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final myGroupsData = await supabase
          .from('ride_groups')
          .select()
          .eq('creator_id', currentUser.id)
          .order('created_at', ascending: false);

      final pendingInviteData = await supabase
          .from('ride_group_invites')
          .select('group_id, group_name, inviter_id, status')
          .eq('invitee_id', currentUser.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final acceptedInviteData = await supabase
          .from('ride_group_invites')
          .select('group_id, group_name, inviter_id, status')
          .eq('invitee_id', currentUser.id)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final myGroups = List<Map<String, dynamic>>.from(
        myGroupsData,
      ).map((row) => _rowToGroup(row, leaderName: 'You', leaderId: currentUser.id)).toList();

      final seenGroupIds = myGroups.map((group) => group.id).toSet();
      final acceptedInvites = List<Map<String, dynamic>>.from(
        acceptedInviteData,
      );
      final pendingInvites = List<Map<String, dynamic>>.from(pendingInviteData);
      final inviteGroupIds = <String>{
        for (final invite in acceptedInvites)
          if ((invite['group_id'] as String?)?.isNotEmpty == true)
            invite['group_id'] as String,
        for (final invite in pendingInvites)
          if ((invite['group_id'] as String?)?.isNotEmpty == true)
            invite['group_id'] as String,
      }.toList();
      final inviterIds = <String>{
        for (final invite in acceptedInvites)
          if ((invite['inviter_id'] as String?)?.isNotEmpty == true)
            invite['inviter_id'] as String,
        for (final invite in pendingInvites)
          if ((invite['inviter_id'] as String?)?.isNotEmpty == true)
            invite['inviter_id'] as String,
      }.toList();

      final groupRowsById = await _fetchGroupRows(inviteGroupIds);
      final leaderNamesById = await _fetchLeaderNames(inviterIds);

      for (final invite in acceptedInvites) {
        final groupId = invite['group_id'] as String?;
        if (groupId == null || seenGroupIds.contains(groupId)) continue;

        final groupRow = groupRowsById[groupId];
        if (groupRow == null) continue;

        final inviterId = invite['inviter_id'] as String?;
        final leaderName = leaderNamesById[inviterId] ?? 'Rider';

        myGroups.add(_rowToGroup(groupRow, leaderName: leaderName, leaderId: inviterId));
        seenGroupIds.add(groupId);
      }

      final invitations = <RideGroup>[];

      for (final invite in pendingInvites) {
        final groupId = invite['group_id'] as String?;
        if (groupId == null) continue;

        final groupRow = groupRowsById[groupId];
        if (groupRow == null) continue;

        final inviterId = invite['inviter_id'] as String?;
        final leaderName = leaderNamesById[inviterId] ?? 'Rider';

        invitations.add(_rowToGroup(groupRow, leaderName: leaderName, leaderId: inviterId));
      }

      // Surface the ride leader's Pioneer status next to the Led by
      // line on each group card.
      final leaderIds = <String>{
        for (final group in [...myGroups, ...invitations])
          if ((group.leaderId ?? '').isNotEmpty) group.leaderId!,
      }.toList();
      final pioneerStatuses =
          await PioneerService.instance.getStatuses(leaderIds);
      for (final group in [...myGroups, ...invitations]) {
        final status = group.leaderId == null
            ? null
            : pioneerStatuses[group.leaderId];
        group.isPioneer = status != null;
        group.pioneerNumber = status?.number;
      }

      if (mounted) {
        setState(() {
          _myGroups
            ..clear()
            ..addAll(myGroups);
          _invitations
            ..clear()
            ..addAll(invitations);
          _selectedRideIds.clear();
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('RideGroupsScreen: _loadGroups failed: $e\n$stack');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'load_groups',
        error: e,
        stackTrace: stack,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchGroupRows(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return {};

    try {
      final rows = await Supabase.instance.client
          .from('ride_groups')
          .select()
          .inFilter('id', groupIds);

      return {
        for (final row in List<Map<String, dynamic>>.from(rows))
          if ((row['id'] as String?)?.isNotEmpty == true)
            row['id'] as String: row,
      };
    } catch (e) {
      debugPrint('RideGroupsScreen: group batch fetch failed: $e');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'fetch_group_rows',
        error: e,
        severity: 'warning',
        context: {'group_count': groupIds.length},
      );
      return {};
    }
  }

  Future<Map<String, String>> _fetchLeaderNames(List<String> inviterIds) async {
    if (inviterIds.isEmpty) return {};

    try {
      final profiles = await Supabase.instance.client
          .from('user_profiles')
          .select('id, full_name, email')
          .inFilter('id', inviterIds);

      final names = <String, String>{};

      for (final profile in List<Map<String, dynamic>>.from(profiles)) {
        final id = profile['id'] as String?;
        if (id == null || id.isEmpty) continue;

        final fullName = profile['full_name'] as String?;
        final email = profile['email'] as String?;

        if (fullName != null && fullName.trim().isNotEmpty) {
          names[id] = fullName.trim();
        } else if (email != null && email.isNotEmpty) {
          names[id] = email.split('@').first;
        } else {
          names[id] = 'Rider';
        }
      }

      return names;
    } catch (e) {
      debugPrint('RideGroupsScreen: leader profiles batch fetch failed: $e');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'fetch_leader_names',
        error: e,
        severity: 'warning',
        context: {'leader_count': inviterIds.length},
      );
      return {};
    }
  }

  RideGroup _rowToGroup(
    Map<String, dynamic> row, {
    String leaderName = 'You',
    String? leaderId,
  }) {
    final rideDate = row['ride_date'] != null
        ? DateTime.tryParse(row['ride_date'] as String) ??
              DateTime.now().add(const Duration(days: 3))
        : DateTime.now().add(const Duration(days: 3));

    return RideGroup(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? 'Group Ride',
      route: row['route'] as String? ?? '',
      date: rideDate,
      maxRiders: (row['max_riders'] as int?) ?? 4,
      memberCount: (row['member_count'] as int?) ?? 1,
      leaderName: leaderName,
      leaderId: leaderId,
      rideCommunity: row['ride_community'] as String? ?? 'motorcycle',
      rideType: row['ride_type'] as String? ?? 'Scenic',
      difficulty: row['difficulty'] as String? ?? 'Moderate',
      duration: row['duration'] as String? ?? '2h',
      routeImageUrl:
          row['route_image_url'] as String? ??
          'https://images.pexels.com/photos/1119796/pexels-photo-1119796.jpeg',
      routePolyline: _parseRoutePolyline(row['route_polyline']),
      routeWaypoints: _parseRouteWaypoints(row['route_waypoints']),
    );
  }

  List<LatLng> _parseRoutePolyline(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((point) {
          final lat = point['lat'];
          final lng = point['lng'];
          if (lat is! num || lng is! num) return null;
          return LatLng(lat.toDouble(), lng.toDouble());
        })
        .whereType<LatLng>()
        .toList();
  }

  List<String> _parseRouteWaypoints(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  List<LatLng> _routeWaypointPoints(List<String> waypoints) {
    return waypoints
        .map((value) {
          final parts = value.split(',');
          if (parts.length != 2) return null;
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
  }

  List<Map<String, double>> _routePolylineToJson(List<LatLng> points) {
    return points
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList();
  }

  bool _postgrestErrorMentions(PostgrestException error, String value) {
    final text = '${error.message} ${error.details} ${error.hint} ${error.code}'
        .toLowerCase();
    return text.contains(value.toLowerCase());
  }

  Future<Map<String, dynamic>> _insertRideGroup(
    SupabaseClient supabase,
    Map<String, dynamic> payload,
  ) async {
    final insertPayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final inserted = await supabase
            .from('ride_groups')
            .insert(insertPayload)
            .select()
            .single();

        return Map<String, dynamic>.from(inserted);
      } on PostgrestException catch (e) {
        final missingRouteColumns =
            _postgrestErrorMentions(e, 'route_polyline') ||
            _postgrestErrorMentions(e, 'route_waypoints');

        if (missingRouteColumns &&
            (insertPayload.containsKey('route_polyline') ||
                insertPayload.containsKey('route_waypoints'))) {
          debugPrint(
            'RideGroupsScreen: route columns missing, retrying basic group insert: $e',
          );
          await DiagnosticsService.instance.logError(
            feature: 'ride_groups',
            action: 'insert_group_retry_without_route_columns',
            error: e,
            severity: 'warning',
            context: {'attempt': attempt + 1},
          );
          insertPayload.remove('route_polyline');
          insertPayload.remove('route_waypoints');
          continue;
        }

        if (_postgrestErrorMentions(e, 'ride_community') &&
            insertPayload.containsKey('ride_community')) {
          debugPrint(
            'RideGroupsScreen: ride_community column missing, retrying basic group insert: $e',
          );
          await DiagnosticsService.instance.logError(
            feature: 'ride_groups',
            action: 'insert_group_retry_without_ride_community',
            error: e,
            severity: 'warning',
            context: {'attempt': attempt + 1},
          );
          insertPayload.remove('ride_community');
          continue;
        }

        rethrow;
      }
    }

    await DiagnosticsService.instance.logError(
      feature: 'ride_groups',
      action: 'insert_group_exhausted_retries',
      error: 'Unable to create ride group',
      context: {'payload_keys': insertPayload.keys.toList()},
    );
    throw Exception('Unable to create ride group');
  }

  Future<void> _deleteSelectedRides() async {
    final selectedGroups = _myGroups
        .where((group) => _selectedRideIds.contains(group.id))
        .where(_canDeleteRide)
        .toList();

    if (selectedGroups.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete rides?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete ${selectedGroups.length} ride${selectedGroups.length == 1 ? '' : 's'}, including invites, live ride sessions, locations, and chat messages.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final group in selectedGroups) {
        await _deleteRideData(group.id);
      }

      if (mounted) {
        setState(() {
          _cleanupMode = false;
          _selectedRideIds.clear();
        });

        await _loadGroups();

        if (!mounted) return;
        AppToast.show(
          context,
          message: 'Ride${selectedGroups.length == 1 ? '' : 's'} deleted',
          type: ToastType.success,
        );
      }
    } catch (e, stack) {
      debugPrint('RideGroupsScreen: delete rides failed: $e\n$stack');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'delete_selected_rides',
        error: e,
        stackTrace: stack,
        context: {'selected_count': selectedGroups.length},
      );

      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not delete selected rides',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _deleteRideData(String groupId) async {
    await Supabase.instance.client.rpc(
      'delete_old_ride_group',
      params: {'group_id_param': groupId},
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGroupModalWidget(
        onCreate: (group, invitees) async {
          try {
            final supabase = Supabase.instance.client;
            final currentUser = supabase.auth.currentUser;

            if (currentUser == null) {
              if (mounted) {
                AppToast.show(
                  context,
                  message: 'You must be signed in to create a ride',
                  type: ToastType.error,
                );
              }
              return;
            }

            final inserted = await _insertRideGroup(supabase, {
              'creator_id': currentUser.id,
              'name': group.name,
              'route': group.route,
              'ride_date': group.date.toIso8601String(),
              'max_riders': group.maxRiders,
              'member_count': 1,
              'leader_name': 'You',
              'ride_community': group.rideCommunity,
              'ride_type': group.rideType,
              'difficulty': group.difficulty,
              'duration': group.duration,
              'route_image_url': group.routeImageUrl,
              'route_polyline': _routePolylineToJson(group.routePolyline),
              'route_waypoints': group.routeWaypoints,
            });

            final groupId = inserted['id'] as String?;

            if (groupId == null) {
              throw Exception('Ride group was created without an id');
            }

            if (invitees.isNotEmpty) {
              final createdAt = DateTime.now().toIso8601String();

              final inviteRows = invitees.map((inviteeId) {
                return {
                  'group_id': groupId,
                  'group_name': group.name,
                  'inviter_id': currentUser.id,
                  'invitee_id': inviteeId,
                  'status': 'pending',
                  'created_at': createdAt,
                };
              }).toList();

              await supabase.from('ride_group_invites').insert(inviteRows);

              final notificationRows = invitees.map((inviteeId) {
                return {
                  'user_id': inviteeId,
                  'notification_type': 'ride_group_invite',
                  'title': 'New group ride invite',
                  'message': 'You have been invited to ${group.name}',
                  'is_read': false,
                  'action_route': '/ride-groups-screen',
                  'action_arguments': {
                    'group_id': groupId,
                    'group_name': group.name,
                    'source': 'ride_group_invite',
                  },
                  'reference_id': groupId,
                  'created_at': createdAt,
                };
              }).toList();

              try {
                await supabase.from('notifications').insert(notificationRows);
              } catch (e) {
                debugPrint(
                  'RideGroupsScreen: invite notifications skipped: $e',
                );
                await DiagnosticsService.instance.logError(
                  feature: 'ride_groups',
                  action: 'create_invite_notifications',
                  error: e,
                  severity: 'warning',
                  context: {
                    'group_id': groupId,
                    'invitee_count': invitees.length,
                  },
                );
              }
            }

            await AnalyticsService.instance.logRideGroupCreated(
              groupId: groupId,
              inviteeCount: invitees.length,
              hasPlannedRoute: group.routePolyline.length >= 2,
              rideCommunity: group.rideCommunity,
            );

            await _loadGroups();

            if (mounted) {
              AppToast.show(
                context,
                message: invitees.isNotEmpty
                    ? 'Group ride created & ${invitees.length} rider${invitees.length > 1 ? 's' : ''} invited!'
                    : 'Group ride created!',
                type: ToastType.success,
              );
            }
          } catch (e, stack) {
            debugPrint('RideGroupsScreen: create group failed: $e\n$stack');
            await DiagnosticsService.instance.logError(
              feature: 'ride_groups',
              action: 'create_group',
              error: e,
              stackTrace: stack,
              context: {'invitee_count': invitees.length},
            );

            if (mounted) {
              AppToast.show(
                context,
                message: 'Could not create or share the ride',
                type: ToastType.error,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _acceptInvitation(RideGroup group) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase
          .from('ride_group_invites')
          .update({'status': 'accepted'})
          .eq('group_id', group.id)
          .eq('invitee_id', currentUser.id);

      try {
        await supabase.rpc(
          'increment_group_member_count',
          params: {'group_id_param': group.id},
        );
      } catch (e) {
        debugPrint('RideGroupsScreen: member count increment skipped: $e');
        await DiagnosticsService.instance.logError(
          feature: 'ride_groups',
          action: 'increment_member_count',
          error: e,
          severity: 'warning',
          context: {'group_id': group.id},
        );
      }

      await AnalyticsService.instance.logRideGroupJoined(groupId: group.id);
      await _loadGroups();

      if (mounted) {
        _tabController.animateTo(0);
        AppToast.show(
          context,
          message: 'Joined ${group.name}!',
          type: ToastType.success,
        );
      }
    } catch (e, stack) {
      debugPrint('RideGroupsScreen: accept invitation failed: $e\n$stack');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'accept_invitation',
        error: e,
        stackTrace: stack,
        context: {'group_id': group.id},
      );

      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not join ride',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _declineInvitation(RideGroup group) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase
          .from('ride_group_invites')
          .update({'status': 'declined'})
          .eq('group_id', group.id)
          .eq('invitee_id', currentUser.id);

      await _loadGroups();
    } catch (e) {
      debugPrint('RideGroupsScreen: decline invitation failed: $e');
      await DiagnosticsService.instance.logError(
        feature: 'ride_groups',
        action: 'decline_invitation',
        error: e,
        severity: 'warning',
        context: {'group_id': group.id},
      );
      setState(() => _invitations.remove(group));
    }
  }

  Future<void> _markImHome(RideGroup group) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    setState(() => _imHomeStatus[group.id] = true);

    try {
      if (currentUser != null) {
        await supabase.from('ride_group_members').upsert({
          'group_id': group.id,
          'user_id': currentUser.id,
          'im_home': true,
          'im_home_at': DateTime.now().toIso8601String(),
        }, onConflict: 'group_id,user_id');
      }
    } catch (e) {
      debugPrint('RideGroupsScreen: mark home sync skipped/failed: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
      AppToast.show(
        context,
        message: 'You\'re home safe! Your group has been notified.',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;
    final hasRideGroupAccess =
        isPremium ||
        _isLoading ||
        _invitations.isNotEmpty ||
        _myGroups.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 28),
            SizedBox(width: 2.w),
            Text(
              'Ride Groups',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 2.w),
            if (isPremium)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  'Premium',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFB347),
                  ),
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: null,
        bottom: hasRideGroupAccess
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                indicatorColor: const Color(0xFFE85A4F),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
                tabs: [
                  Tab(text: 'My Groups (${_myGroups.length})'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Invitations'),
                        if (_invitations.isNotEmpty) ...[
                          SizedBox(width: 1.w),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE85A4F),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_invitations.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
      ),
      body: hasRideGroupAccess ? _buildPremiumContent() : _buildGate(),
      floatingActionButton: isPremium && !_cleanupMode
          ? FloatingActionButton.extended(
              onPressed: _showCreateModal,
              backgroundColor: const Color(0xFFE85A4F),
              icon: Icon(AppIcons.add),
              label: Text(
                'Create Ride',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildGate() {
    return PremiumGateWidget(
      featureName: 'Ride Groups',
      description:
          'Create group rides with matched riders. Invited riders can still join rides shared with them.',
      icon: AppIcons.group,
    );
  }

  Widget _buildPremiumContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildCleanupToolbar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGroupsList(_myGroups, isMyGroups: true),
              _buildInvitationsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCleanupToolbar() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _cleanupMode
                ? '${_selectedRideIds.length} selected'
                : 'Manage ride groups',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (_cleanupMode) ...[
            TextButton.icon(
              onPressed: _toggleCleanupMode,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text('Cancel', style: GoogleFonts.dmSans()),
            ),
            SizedBox(width: 2.w),
            ElevatedButton.icon(
              onPressed: _selectedRideIds.isEmpty ? null : _deleteSelectedRides,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text('Delete', style: GoogleFonts.dmSans()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85A4F),
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            IconButton(
              onPressed: _toggleCleanupMode,
              icon: const Icon(Icons.cleaning_services_rounded),
              tooltip: 'Clean up rides',
            ),
            IconButton(
              onPressed: _loadGroups,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupsList(List<RideGroup> groups, {required bool isMyGroups}) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMyGroups ? AppIcons.group : AppIcons.email,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: 2.h),
            Text(
              isMyGroups ? 'No group rides yet' : 'No pending invitations',
              style: GoogleFonts.dmSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              isMyGroups
                  ? 'Accepted ride invites appear here'
                  : 'Invitations from matched riders appear here',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        itemCount: groups.length,
        itemBuilder: (_, i) => _buildGroupListItem(groups[i]),
      ),
    );
  }

  Widget _buildGroupListItem(RideGroup group) {
    final isPast = _isPastRide(group);
    final canDelete = _canDeleteRide(group);
    final isSelected = _selectedRideIds.contains(group.id);

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.0),
        border: _cleanupMode && canDelete
            ? Border.all(
                color: isSelected
                    ? const Color(0xFFE85A4F)
                    : const Color(0xFFE85A4F).withValues(alpha: 0.45),
                width: isSelected ? 2 : 1,
              )
            : isPast
            ? Border.all(
                color: const Color(0xFFE85A4F).withValues(alpha: 0.55),
                width: 1,
              )
            : null,
        color: isPast
            ? const Color(0xFFE85A4F).withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: isPast ? 0.72 : 1,
            child: GroupCardWidget(
              group: group,
              onTap: _cleanupMode
                  ? () => _toggleRideSelection(group)
                  : () => _showGroupDetail(group),
            ),
          ),
          if (isPast)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE85A4F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Past ride',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (_cleanupMode && canDelete)
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () => _toggleRideSelection(group),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE85A4F)
                        : Colors.white.withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE85A4F)),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.delete_outline,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFFE85A4F),
                  ),
                ),
              ),
            ),
          if (_cleanupMode && !canDelete)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvitationsList() {
    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.email,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: 2.h),
            Text(
              'No pending invitations',
              style: GoogleFonts.dmSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Invitations from matched riders appear here',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        itemCount: _invitations.length,
        itemBuilder: (_, i) {
          final group = _invitations[i];

          return Card(
            margin: EdgeInsets.only(bottom: 1.5.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Column(
              children: [
                GroupCardWidget(
                  group: group,
                  onTap: () => _showGroupDetail(group),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _declineInvitation(group),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptInvitation(group),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE85A4F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: Text(
                            'Join Ride',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showGroupDetail(RideGroup group) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isHome = _imHomeStatus[group.id] == true;
          final bottomSafeArea = MediaQuery.of(ctx).viewPadding.bottom;

          return Container(
            height: 75.h,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24.0),
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: 1.5.h),
                Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      5.w,
                      5.w,
                      5.w,
                      5.w + bottomSafeArea + 2.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14.0),
                          child: Image.network(
                            group.routeImageUrl,
                            height: 20.h,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel:
                                '${group.communityLabel} ride route preview',
                            errorBuilder: (_, __, ___) => Container(
                              height: 20.h,
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          group.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          group.route,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        _communityPill(group, theme),
                        SizedBox(height: 1.h),
                        _detailRow(AppIcons.help, group.formattedDate, theme),
                        SizedBox(height: 1.h),
                        _detailRow(AppIcons.timer, group.duration, theme),
                        SizedBox(height: 1.h),
                        _detailRow(
                          AppIcons.group,
                          '${group.memberCount}/${group.maxRiders} riders',
                          theme,
                        ),
                        SizedBox(height: 1.h),
                        _detailRow(
                          group.isBicycle
                              ? Icons.directions_bike_rounded
                              : Icons.motorcycle_rounded,
                          '${group.communityLabel} - ${group.rideType}',
                          theme,
                        ),
                        SizedBox(height: 3.h),
                        _buildLiveRideButton(group, ctx, setModalState),
                        SizedBox(height: 1.5.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isHome ? null : () => _markImHome(group),
                            icon: Icon(
                              isHome
                                  ? Icons.check_circle_rounded
                                  : Icons.home_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              isHome ? 'You\'re Home Safe' : 'I\'m Home',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHome
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF388E3C),
                              disabledBackgroundColor: const Color(0xFF2E7D32),
                              padding: EdgeInsets.symmetric(vertical: 1.8.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 1.5.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(AppIcons.help, size: 18),
                            label: Text(
                              'Open Group Chat',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 1.8.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 1.5.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.pushNamed(
                                context,
                                '/route-planner-screen',
                              );
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Text(
                              'Plan Route',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 1.8.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveRideButton(
    RideGroup group,
    BuildContext ctx,
    StateSetter setModalState,
  ) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _checkActiveRideSession(group.id),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final activeSession = snapshot.data;
        final hasActiveRide = activeSession != null;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => hasActiveRide
                          ? _joinLiveRide(activeSession['id'] as String, group)
                          : _startLiveRide(group),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        hasActiveRide
                            ? Icons.gps_fixed_rounded
                            : group.isBicycle
                            ? Icons.directions_bike_rounded
                            : Icons.motorcycle_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                label: Text(
                  isLoading
                      ? 'Checking...'
                      : hasActiveRide
                      ? 'Join Live Ride'
                      : 'Start Live Ride',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasActiveRide
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF2E7D32),
                  disabledBackgroundColor: const Color(0xFF546E7A),
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _checkActiveRideSession(String groupId) async {
    try {
      final response = await Supabase.instance.client
          .from('live_ride_sessions')
          .select('id, started_by, started_at')
          .eq('ride_group_id', groupId)
          .eq('status', 'active')
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startLiveRide(RideGroup group) async {
    Navigator.of(context).pop();

    final existingSession = await _checkActiveRideSession(group.id);

    if (existingSession != null) {
      final sessionId = existingSession['id'] as String;
      final success = await LiveRideService.instance.joinRide(sessionId);

      if (success && mounted) {
        await LiveRideNavigation.open(
          context,
          sessionId: sessionId,
          initialRouteName: group.route,
          initialRoutePoints: group.routePolyline,
          initialWaypointPoints: _routeWaypointPoints(group.routeWaypoints),
        );
      } else if (mounted) {
        AppToast.show(
          context,
          message:
              LiveRideService.instance.lastError ?? 'Failed to join live ride',
          type: ToastType.error,
        );
      }

      return;
    }

    final session = await LiveRideService.instance.startRide(group.id, null);

    if (session != null && mounted) {
      await LiveRideNavigation.open(
        context,
        sessionId: session.id,
        isCreator: true,
        initialRouteName: group.route,
        initialRoutePoints: group.routePolyline,
        initialWaypointPoints: _routeWaypointPoints(group.routeWaypoints),
      );
    } else if (mounted) {
      AppToast.show(
        context,
        message:
            LiveRideService.instance.lastError ?? 'Failed to start live ride',
        type: ToastType.error,
      );
    }
  }

  Future<void> _joinLiveRide(String sessionId, RideGroup group) async {
    Navigator.of(context).pop();

    final success = await LiveRideService.instance.joinRide(sessionId);

    if (success && mounted) {
      await LiveRideNavigation.open(
        context,
        sessionId: sessionId,
        initialRouteName: group.route,
        initialRoutePoints: group.routePolyline,
        initialWaypointPoints: _routeWaypointPoints(group.routeWaypoints),
      );
    } else if (mounted) {
      AppToast.show(
        context,
        message:
            LiveRideService.instance.lastError ?? 'Failed to join live ride',
        type: ToastType.error,
      );
    }
  }

  Widget _detailRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        SizedBox(width: 2.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _communityPill(RideGroup group, ThemeData theme) {
    final color = group.isBicycle
        ? const Color(0xFF2E7D32)
        : theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            group.isBicycle
                ? Icons.directions_bike_rounded
                : Icons.motorcycle_rounded,
            size: 16,
            color: color,
          ),
          SizedBox(width: 1.5.w),
          Text(
            '${group.communityLabel} Ride',
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
