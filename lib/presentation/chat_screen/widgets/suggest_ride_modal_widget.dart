import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class SuggestRideModalWidget extends StatefulWidget {
  final String riderName;
  final VoidCallback onClose;
  final Function(Map<String, String>) onSend;

  const SuggestRideModalWidget({
    super.key,
    required this.riderName,
    required this.onClose,
    required this.onSend,
  });

  @override
  State<SuggestRideModalWidget> createState() => _SuggestRideModalWidgetState();
}

class _SuggestRideModalWidgetState extends State<SuggestRideModalWidget> {
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _meetController = TextEditingController();
  String _selectedDate = 'This Saturday';
  String _selectedTime = '9:00 AM';

  final List<String> _dates = [
    'Today',
    'Tomorrow',
    'This Saturday',
    'This Sunday',
    'Next Weekend',
  ];

  final List<String> _times = [
    '7:00 AM',
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '12:00 PM',
    '2:00 PM',
  ];

  @override
  void dispose() {
    _routeController.dispose();
    _meetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFE85A4F).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Route / Destination'),
                SizedBox(height: 0.5.h),
                _buildTextField(_routeController, 'e.g. Pacific Coast Highway'),
                SizedBox(height: 1.5.h),
                _buildLabel('Meet Point'),
                SizedBox(height: 0.5.h),
                _buildTextField(_meetController, 'e.g. Starbucks on Main St'),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Date'),
                          SizedBox(height: 0.5.h),
                          _buildDropdown(
                            _dates,
                            _selectedDate,
                            (v) => setState(() => _selectedDate = v!),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Time'),
                          SizedBox(height: 0.5.h),
                          _buildDropdown(
                            _times,
                            _selectedTime,
                            (v) => setState(() => _selectedTime = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSend({
                        'route': _routeController.text,
                        'meet': _meetController.text,
                        'date': _selectedDate,
                        'time': _selectedTime,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85A4F),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 1.4.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: Text(
                      'Send Ride Suggestion',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 1.5.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE85A4F).withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Row(
        children: [
          Icon(AppIcons.help, color: const Color(0xFFE85A4F), size: 20),
          SizedBox(width: 2.w),
          Text(
            'Suggest a Ride to ${widget.riderName}',
            style: GoogleFonts.dmSans(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE85A4F),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(
              AppIcons.close,
              size: 18,
              color: const Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF666666),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.dmSans(
        fontSize: 12.5.sp,
        color: const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 12.sp,
          color: const Color(0xFFBBBBBB),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFE85A4F), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: const Color(0xFF1A1A1A),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
