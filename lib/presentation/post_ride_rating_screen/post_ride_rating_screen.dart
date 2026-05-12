import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/offline_queue_service.dart';
import './widgets/rider_summary_card_widget.dart';
import './widgets/star_rating_widget.dart';
import './widgets/category_ratings_widget.dart';
import './widgets/safety_tags_widget.dart';
import '../../widgets/app_logo_widget.dart';

class PostRideRatingScreen extends StatefulWidget {
  const PostRideRatingScreen({super.key});

  static Future<bool?> show(
    BuildContext context, {
    required String reviewedId,
    required String reviewedName,
    String? reviewedImage,
    String bikeInfo = 'Motorcycle',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostRideRatingScreen(),
      routeSettings: RouteSettings(
        arguments: {
          'reviewedId': reviewedId,
          'reviewedName': reviewedName,
          'reviewedImage': reviewedImage,
          'bikeInfo': bikeInfo,
        },
      ),
    );
  }

  @override
  State<PostRideRatingScreen> createState() => _PostRideRatingScreenState();
}

class _PostRideRatingScreenState extends State<PostRideRatingScreen> {
  int _overallRating = 0;
  Map<String, int> _categoryRatings = {};
  Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  String _reviewedId = '';
  String _reviewedName = '';
  String? _reviewedImage;
  String _bikeInfo = 'Motorcycle';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _reviewedId = args['reviewedId'] as String? ?? '';
      _reviewedName = args['reviewedName'] as String? ?? 'Rider';
      _reviewedImage = args['reviewedImage'] as String?;
      _bikeInfo = args['bikeInfo'] as String? ?? 'Motorcycle';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_overallRating == 0) return;
    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final reviewedId = _reviewedId.isNotEmpty ? _reviewedId : user.id;
      final comment = _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim();

      final isOnline = await OfflineQueueService.isOnline();

      if (isOnline) {
        try {
          await client.from('ride_ratings').insert({
            'reviewer_id': user.id,
            'reviewed_id': reviewedId,
            'stars': _overallRating,
            'category_ratings': _categoryRatings.isEmpty
                ? {}
                : _categoryRatings,
            'safety_tags': _selectedTags.toList(),
            'comment': comment,
          });
        } catch (e) {
          // Insert failed — queue for retry
          await OfflineQueueService.instance.enqueueRating(
            QueuedRating(
              localId: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
              reviewerId: user.id,
              reviewedId: reviewedId,
              stars: _overallRating,
              categoryRatings: Map<String, int>.from(_categoryRatings),
              safetyTags: _selectedTags.toList(),
              comment: comment,
              createdAt: DateTime.now(),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rating saved — will submit when back online.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // Offline — queue the rating
        await OfflineQueueService.instance.enqueueRating(
          QueuedRating(
            localId: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
            reviewerId: user.id,
            reviewedId: reviewedId,
            stars: _overallRating,
            categoryRatings: Map<String, int>.from(_categoryRatings),
            safetyTags: _selectedTags.toList(),
            comment: comment,
            createdAt: DateTime.now(),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You\'re offline. Rating queued and will sync when connected.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String get _ratingLabel {
    switch (_overallRating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent!';
      default:
        return 'Tap to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragIndicator(theme),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: _submitted ? _buildSuccessState(theme) : _buildForm(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragIndicator(ThemeData theme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          SizedBox(height: 1.2.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogoMark(size: 7.w),
              SizedBox(width: 2.w),
              Text(
                'RydMatch',
                style: GoogleFonts.dmSans(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 1.h),
        Row(
          children: [
            Expanded(
              child: Text(
                'Rate Your Ride',
                style: GoogleFonts.dmSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B365D),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: Icon(
                Icons.close_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        RiderSummaryCardWidget(
          riderName: _reviewedName,
          riderImage: _reviewedImage,
          bikeInfo: _bikeInfo,
        ),
        SizedBox(height: 3.h),
        Center(
          child: Text(
            'Overall Experience',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: 1.h),
        StarRatingWidget(
          rating: _overallRating,
          starSize: 44.0,
          onRatingChanged: (r) => setState(() => _overallRating = r),
        ),
        SizedBox(height: 0.8.h),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_overallRating),
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _overallRating > 0
                    ? const Color(0xFFFF8C00)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SizedBox(height: 2.5.h),
        CategoryRatingsWidget(
          categoryRatings: _categoryRatings,
          onChanged: (r) => setState(() => _categoryRatings = r),
        ),
        SizedBox(height: 2.h),
        SafetyTagsWidget(
          selectedTags: _selectedTags,
          onChanged: (tags) => setState(() => _selectedTags = tags),
        ),
        SizedBox(height: 2.h),
        _buildCommentField(theme),
        SizedBox(height: 3.h),
        _buildSubmitButton(theme),
        SizedBox(height: 3.h),
      ],
    );
  }

  Widget _buildCommentField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a Comment (Optional)',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: _commentController,
          maxLength: 300,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Share your experience...',
            counterText: '${_commentController.text.length}/300',
            counterStyle: GoogleFonts.dmSans(
              fontSize: 10.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    final canSubmit = _overallRating > 0 && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitRating : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE85A4F),
          disabledBackgroundColor: theme.colorScheme.outline.withValues(
            alpha: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          elevation: canSubmit ? 2 : 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'Submit Rating',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: canSubmit
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5A27).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2D5A27),
                size: 48,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Rating Submitted!',
            style: GoogleFonts.dmSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Thanks for helping build trust in the community.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _overallRating,
              (i) => const Icon(
                Icons.star_rounded,
                color: Color(0xFFFF8C00),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
