import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  static const Color _navyColor = Color(0xFF1B365D);
  static const Color _orangeColor = Color(0xFFE85A4F);

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final data = await supabase
            .from('user_blocks')
            .select(
              'id, blocked_id, created_at, user_profiles!user_blocks_blocked_id_fkey(id, full_name, email)',
            )
            .eq('blocker_id', currentUser.id)
            .order('created_at', ascending: false);

        if (mounted) {
          final rows = List<Map<String, dynamic>>.from(data);
          setState(() {
            _blockedUsers = rows.map((b) {
              final profile = b['user_profiles'] as Map<String, dynamic>?;
              final name =
                  (profile?['full_name'] as String?)?.isNotEmpty == true
                  ? profile!['full_name'] as String
                  : (profile?['email'] as String?)?.split('@').first ??
                        'Blocked User';
              return <String, dynamic>{
                'blockId': b['id'],
                'id': b['blocked_id'],
                'name': name,
                'image': null,
                'bikeType': '',
              };
            }).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {
      // Fall through to empty state
    }
    if (mounted) {
      setState(() {
        _blockedUsers = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Unblock ${user['name']}?',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            color: _navyColor,
          ),
        ),
        content: Text(
          'They will be able to see your profile and contact you again.',
          style: GoogleFonts.dmSans(fontSize: 12.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: _navyColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _orangeColor),
            child: Text(
              'Unblock',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null && user['blockId'] != null) {
        await supabase.from('user_blocks').delete().eq('id', user['blockId']);
      }
    } catch (_) {
      // Proceed with local removal
    }

    if (mounted) {
      setState(() => _blockedUsers.removeWhere((u) => u['id'] == user['id']));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user['name']} has been unblocked',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: _navyColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _navyColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Blocked Users',
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orangeColor))
          : _blockedUsers.isEmpty
          ? _buildEmptyState(theme)
          : RefreshIndicator(
              onRefresh: _loadBlockedUsers,
              color: _orangeColor,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                itemCount: _blockedUsers.length,
                separatorBuilder: (_, __) => SizedBox(height: 1.h),
                itemBuilder: (context, index) {
                  final user = _blockedUsers[index];
                  return _buildBlockedUserCard(theme, user);
                },
              ),
            ),
    );
  }

  Widget _buildBlockedUserCard(ThemeData theme, Map<String, dynamic> user) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _navyColor.withValues(alpha: 0.08),
            backgroundImage: user['image'] != null
                ? NetworkImage(user['image'] as String)
                : null,
            child: user['image'] == null
                ? Icon(
                    Icons.person,
                    color: _navyColor.withValues(alpha: 0.5),
                    size: 28,
                  )
                : null,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((user['bikeType'] as String).isNotEmpty)
                  Text(
                    user['bikeType'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unblockUser(user),
            style: TextButton.styleFrom(
              foregroundColor: _orangeColor,
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: BorderSide(color: _orangeColor.withValues(alpha: 0.4)),
              ),
            ),
            child: Text(
              'Unblock',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: _orangeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _navyColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                size: 36,
                color: _navyColor.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'No Blocked Users',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _navyColor,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Users you block will appear here. You can unblock them at any time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
