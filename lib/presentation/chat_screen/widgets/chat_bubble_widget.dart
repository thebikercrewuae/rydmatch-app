import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class ChatBubbleWidget extends StatelessWidget {
  final String message;
  final String timestamp;
  final bool isSender;
  final String? deliveryStatus;
  final bool isImage;
  final String? imageUrl;
  final VoidCallback? onLongPress;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.timestamp,
    required this.isSender,
    this.deliveryStatus,
    this.isImage = false,
    this.imageUrl,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress?.call();
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: 70.w),
          margin: EdgeInsets.only(
            top: 0.4.h,
            bottom: 0.4.h,
            left: isSender ? 8.w : 2.w,
            right: isSender ? 2.w : 8.w,
          ),
          decoration: BoxDecoration(
            color: isSender ? const Color(0xFFE85A4F) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18.0),
              topRight: const Radius.circular(18.0),
              bottomLeft: Radius.circular(isSender ? 18.0 : 4.0),
              bottomRight: Radius.circular(isSender ? 4.0 : 18.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isImage && imageUrl != null
              ? _buildImageBubble()
              : _buildTextBubble(),
        ),
      ),
    );
  }

  Widget _buildTextBubble() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 13.5.sp,
              color: isSender ? Colors.white : const Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
          SizedBox(height: 0.4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timestamp,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  color: isSender
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF999999),
                ),
              ),
              if (isSender) ...[SizedBox(width: 1.w), _buildDeliveryTicks()],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageBubble() {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18.0),
        topRight: const Radius.circular(18.0),
        bottomLeft: Radius.circular(isSender ? 18.0 : 4.0),
        bottomRight: Radius.circular(isSender ? 4.0 : 18.0),
      ),
      child: Stack(
        children: [
          Image.network(
            imageUrl!,
            width: 55.w,
            height: 30.h,
            fit: BoxFit.cover,
            semanticLabel: 'Shared ride photo',
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: Colors.white,
                    ),
                  ),
                  if (isSender) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryTicks(onDark: true),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds WhatsApp-style delivery tick indicators:
  /// - sending: single grey clock icon
  /// - sent: single grey tick
  /// - delivered: double grey ticks
  /// - read: double blue ticks
  /// - failed: red exclamation
  Widget _buildDeliveryTicks({bool onDark = false}) {
    final status = deliveryStatus ?? 'sent';

    switch (status) {
      case 'sending':
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: onDark
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.65),
        );

      case 'sent':
        // Single grey tick
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: onDark
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.65),
        );

      case 'delivered':
        // Double grey ticks
        return _DoubleTick(
          color: onDark
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.65),
        );

      case 'read':
        // Double blue ticks
        return _DoubleTick(
          color: onDark ? const Color(0xFF53BDEB) : const Color(0xFF90D0F0),
        );

      case 'failed':
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: onDark ? Colors.red[300] : Colors.red[200],
        );

      default:
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.65),
        );
    }
  }
}

/// Renders two overlapping check marks (WhatsApp-style double tick).
class _DoubleTick extends StatelessWidget {
  final Color color;

  const _DoubleTick({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(Icons.check_rounded, size: 14, color: color),
          ),
          Positioned(
            left: 5,
            child: Icon(Icons.check_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}
