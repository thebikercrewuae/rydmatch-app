import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttachPhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onSuggestRide;
  final VoidCallback? onPlanRoute;
  final ValueChanged<String> onChanged;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachPhoto,
    required this.onShareLocation,
    required this.onSuggestRide,
    this.onPlanRoute,
    required this.onChanged,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _hasText = false;
  bool _showExtras = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() => _hasText = widget.controller.text.trim().isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showExtras) _buildQuickActions(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showExtras = !_showExtras),
                    child: Container(
                      width: 9.w,
                      height: 9.w,
                      decoration: BoxDecoration(
                        color: _showExtras
                            ? const Color(0xFFE85A4F)
                            : const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showExtras ? AppIcons.close : AppIcons.add,
                        size: 18,
                        color: _showExtras
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 12.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        onChanged: widget.onChanged,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5.sp,
                          color: const Color(0xFF1A1A1A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 13.5.sp,
                            color: const Color(0xFF999999),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.2.h,
                          ),
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  GestureDetector(
                    onTap: _hasText ? widget.onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 9.w,
                      height: 9.w,
                      decoration: BoxDecoration(
                        color: _hasText
                            ? const Color(0xFFE85A4F)
                            : const Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.send,
                        size: 18,
                        color: _hasText
                            ? Colors.white
                            : const Color(0xFF999999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionChip(
              icon: AppIcons.camera,
              label: 'Photo',
              color: const Color(0xFF1B365D),
              onTap: widget.onAttachPhoto,
            ),
            SizedBox(width: 2.w),
            _buildActionChip(
              icon: AppIcons.help,
              label: 'Location',
              color: const Color(0xFF2D5A27),
              onTap: widget.onShareLocation,
            ),
            SizedBox(width: 2.w),
            _buildActionChip(
              icon: AppIcons.route,
              label: 'Suggest Ride',
              color: const Color(0xFFE85A4F),
              onTap: widget.onSuggestRide,
            ),
            SizedBox(width: 2.w),
            _buildActionChip(
              icon: Icons.map_outlined,
              label: 'Plan Route',
              color: const Color(0xFF4A7CC7),
              onTap: widget.onPlanRoute ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            SizedBox(width: 1.w),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
