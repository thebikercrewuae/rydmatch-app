import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class CountryCodeSelectorWidget extends StatefulWidget {
  final Function(String code, String flag) onSelected;
  final String selectedCode;
  final String selectedFlag;

  const CountryCodeSelectorWidget({
    super.key,
    required this.onSelected,
    required this.selectedCode,
    required this.selectedFlag,
  });

  @override
  State<CountryCodeSelectorWidget> createState() =>
      _CountryCodeSelectorWidgetState();
}

class _CountryCodeSelectorWidgetState extends State<CountryCodeSelectorWidget> {
  static const List<Map<String, String>> _allCountries = [
    {'flag': '🇦🇫', 'code': '+93', 'name': 'Afghanistan'},
    {'flag': '🇦🇱', 'code': '+355', 'name': 'Albania'},
    {'flag': '🇩🇿', 'code': '+213', 'name': 'Algeria'},
    {'flag': '🇦🇩', 'code': '+376', 'name': 'Andorra'},
    {'flag': '🇦🇴', 'code': '+244', 'name': 'Angola'},
    {'flag': '🇦🇬', 'code': '+1-268', 'name': 'Antigua and Barbuda'},
    {'flag': '🇦🇷', 'code': '+54', 'name': 'Argentina'},
    {'flag': '🇦🇲', 'code': '+374', 'name': 'Armenia'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇦🇹', 'code': '+43', 'name': 'Austria'},
    {'flag': '🇦🇿', 'code': '+994', 'name': 'Azerbaijan'},
    {'flag': '🇧🇸', 'code': '+1-242', 'name': 'Bahamas'},
    {'flag': '🇧🇭', 'code': '+973', 'name': 'Bahrain'},
    {'flag': '🇧🇩', 'code': '+880', 'name': 'Bangladesh'},
    {'flag': '🇧🇧', 'code': '+1-246', 'name': 'Barbados'},
    {'flag': '🇧🇾', 'code': '+375', 'name': 'Belarus'},
    {'flag': '🇧🇪', 'code': '+32', 'name': 'Belgium'},
    {'flag': '🇧🇿', 'code': '+501', 'name': 'Belize'},
    {'flag': '🇧🇯', 'code': '+229', 'name': 'Benin'},
    {'flag': '🇧🇹', 'code': '+975', 'name': 'Bhutan'},
    {'flag': '🇧🇴', 'code': '+591', 'name': 'Bolivia'},
    {'flag': '🇧🇦', 'code': '+387', 'name': 'Bosnia and Herzegovina'},
    {'flag': '🇧🇼', 'code': '+267', 'name': 'Botswana'},
    {'flag': '🇧🇷', 'code': '+55', 'name': 'Brazil'},
    {'flag': '🇧🇳', 'code': '+673', 'name': 'Brunei'},
    {'flag': '🇧🇬', 'code': '+359', 'name': 'Bulgaria'},
    {'flag': '🇧🇫', 'code': '+226', 'name': 'Burkina Faso'},
    {'flag': '🇧🇮', 'code': '+257', 'name': 'Burundi'},
    {'flag': '🇨🇻', 'code': '+238', 'name': 'Cabo Verde'},
    {'flag': '🇰🇭', 'code': '+855', 'name': 'Cambodia'},
    {'flag': '🇨🇲', 'code': '+237', 'name': 'Cameroon'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇨🇫', 'code': '+236', 'name': 'Central African Republic'},
    {'flag': '🇹🇩', 'code': '+235', 'name': 'Chad'},
    {'flag': '🇨🇱', 'code': '+56', 'name': 'Chile'},
    {'flag': '🇨🇳', 'code': '+86', 'name': 'China'},
    {'flag': '🇨🇴', 'code': '+57', 'name': 'Colombia'},
    {'flag': '🇰🇲', 'code': '+269', 'name': 'Comoros'},
    {'flag': '🇨🇬', 'code': '+242', 'name': 'Congo'},
    {'flag': '🇨🇩', 'code': '+243', 'name': 'Congo (DRC)'},
    {'flag': '🇨🇷', 'code': '+506', 'name': 'Costa Rica'},
    {'flag': '🇭🇷', 'code': '+385', 'name': 'Croatia'},
    {'flag': '🇨🇺', 'code': '+53', 'name': 'Cuba'},
    {'flag': '🇨🇾', 'code': '+357', 'name': 'Cyprus'},
    {'flag': '🇨🇿', 'code': '+420', 'name': 'Czech Republic'},
    {'flag': '🇩🇰', 'code': '+45', 'name': 'Denmark'},
    {'flag': '🇩🇯', 'code': '+253', 'name': 'Djibouti'},
    {'flag': '🇩🇲', 'code': '+1-767', 'name': 'Dominica'},
    {'flag': '🇩🇴', 'code': '+1-809', 'name': 'Dominican Republic'},
    {'flag': '🇪🇨', 'code': '+593', 'name': 'Ecuador'},
    {'flag': '🇪🇬', 'code': '+20', 'name': 'Egypt'},
    {'flag': '🇸🇻', 'code': '+503', 'name': 'El Salvador'},
    {'flag': '🇬🇶', 'code': '+240', 'name': 'Equatorial Guinea'},
    {'flag': '🇪🇷', 'code': '+291', 'name': 'Eritrea'},
    {'flag': '🇪🇪', 'code': '+372', 'name': 'Estonia'},
    {'flag': '🇸🇿', 'code': '+268', 'name': 'Eswatini'},
    {'flag': '🇪🇹', 'code': '+251', 'name': 'Ethiopia'},
    {'flag': '🇫🇯', 'code': '+679', 'name': 'Fiji'},
    {'flag': '🇫🇮', 'code': '+358', 'name': 'Finland'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇬🇦', 'code': '+241', 'name': 'Gabon'},
    {'flag': '🇬🇲', 'code': '+220', 'name': 'Gambia'},
    {'flag': '🇬🇪', 'code': '+995', 'name': 'Georgia'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇬🇭', 'code': '+233', 'name': 'Ghana'},
    {'flag': '🇬🇷', 'code': '+30', 'name': 'Greece'},
    {'flag': '🇬🇩', 'code': '+1-473', 'name': 'Grenada'},
    {'flag': '🇬🇹', 'code': '+502', 'name': 'Guatemala'},
    {'flag': '🇬🇳', 'code': '+224', 'name': 'Guinea'},
    {'flag': '🇬🇼', 'code': '+245', 'name': 'Guinea-Bissau'},
    {'flag': '🇬🇾', 'code': '+592', 'name': 'Guyana'},
    {'flag': '🇭🇹', 'code': '+509', 'name': 'Haiti'},
    {'flag': '🇭🇳', 'code': '+504', 'name': 'Honduras'},
    {'flag': '🇭🇺', 'code': '+36', 'name': 'Hungary'},
    {'flag': '🇮🇸', 'code': '+354', 'name': 'Iceland'},
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇮🇩', 'code': '+62', 'name': 'Indonesia'},
    {'flag': '🇮🇷', 'code': '+98', 'name': 'Iran'},
    {'flag': '🇮🇶', 'code': '+964', 'name': 'Iraq'},
    {'flag': '🇮🇪', 'code': '+353', 'name': 'Ireland'},
    {'flag': '🇮🇱', 'code': '+972', 'name': 'Israel'},
    {'flag': '🇮🇹', 'code': '+39', 'name': 'Italy'},
    {'flag': '🇯🇲', 'code': '+1-876', 'name': 'Jamaica'},
    {'flag': '🇯🇵', 'code': '+81', 'name': 'Japan'},
    {'flag': '🇯🇴', 'code': '+962', 'name': 'Jordan'},
    {'flag': '🇰🇿', 'code': '+7', 'name': 'Kazakhstan'},
    {'flag': '🇰🇪', 'code': '+254', 'name': 'Kenya'},
    {'flag': '🇰🇮', 'code': '+686', 'name': 'Kiribati'},
    {'flag': '🇽🇰', 'code': '+383', 'name': 'Kosovo'},
    {'flag': '🇰🇼', 'code': '+965', 'name': 'Kuwait'},
    {'flag': '🇰🇬', 'code': '+996', 'name': 'Kyrgyzstan'},
    {'flag': '🇱🇦', 'code': '+856', 'name': 'Laos'},
    {'flag': '🇱🇻', 'code': '+371', 'name': 'Latvia'},
    {'flag': '🇱🇧', 'code': '+961', 'name': 'Lebanon'},
    {'flag': '🇱🇸', 'code': '+266', 'name': 'Lesotho'},
    {'flag': '🇱🇷', 'code': '+231', 'name': 'Liberia'},
    {'flag': '🇱🇾', 'code': '+218', 'name': 'Libya'},
    {'flag': '🇱🇮', 'code': '+423', 'name': 'Liechtenstein'},
    {'flag': '🇱🇹', 'code': '+370', 'name': 'Lithuania'},
    {'flag': '🇱🇺', 'code': '+352', 'name': 'Luxembourg'},
    {'flag': '🇲🇬', 'code': '+261', 'name': 'Madagascar'},
    {'flag': '🇲🇼', 'code': '+265', 'name': 'Malawi'},
    {'flag': '🇲🇾', 'code': '+60', 'name': 'Malaysia'},
    {'flag': '🇲🇻', 'code': '+960', 'name': 'Maldives'},
    {'flag': '🇲🇱', 'code': '+223', 'name': 'Mali'},
    {'flag': '🇲🇹', 'code': '+356', 'name': 'Malta'},
    {'flag': '🇲🇭', 'code': '+692', 'name': 'Marshall Islands'},
    {'flag': '🇲🇷', 'code': '+222', 'name': 'Mauritania'},
    {'flag': '🇲🇺', 'code': '+230', 'name': 'Mauritius'},
    {'flag': '🇲🇽', 'code': '+52', 'name': 'Mexico'},
    {'flag': '🇫🇲', 'code': '+691', 'name': 'Micronesia'},
    {'flag': '🇲🇩', 'code': '+373', 'name': 'Moldova'},
    {'flag': '🇲🇨', 'code': '+377', 'name': 'Monaco'},
    {'flag': '🇲🇳', 'code': '+976', 'name': 'Mongolia'},
    {'flag': '🇲🇪', 'code': '+382', 'name': 'Montenegro'},
    {'flag': '🇲🇦', 'code': '+212', 'name': 'Morocco'},
    {'flag': '🇲🇿', 'code': '+258', 'name': 'Mozambique'},
    {'flag': '🇲🇲', 'code': '+95', 'name': 'Myanmar'},
    {'flag': '🇳🇦', 'code': '+264', 'name': 'Namibia'},
    {'flag': '🇳🇷', 'code': '+674', 'name': 'Nauru'},
    {'flag': '🇳🇵', 'code': '+977', 'name': 'Nepal'},
    {'flag': '🇳🇱', 'code': '+31', 'name': 'Netherlands'},
    {'flag': '🇳🇿', 'code': '+64', 'name': 'New Zealand'},
    {'flag': '🇳🇮', 'code': '+505', 'name': 'Nicaragua'},
    {'flag': '🇳🇪', 'code': '+227', 'name': 'Niger'},
    {'flag': '🇳🇬', 'code': '+234', 'name': 'Nigeria'},
    {'flag': '🇲🇰', 'code': '+389', 'name': 'North Macedonia'},
    {'flag': '🇳🇴', 'code': '+47', 'name': 'Norway'},
    {'flag': '🇴🇲', 'code': '+968', 'name': 'Oman'},
    {'flag': '🇵🇰', 'code': '+92', 'name': 'Pakistan'},
    {'flag': '🇵🇼', 'code': '+680', 'name': 'Palau'},
    {'flag': '🇵🇦', 'code': '+507', 'name': 'Panama'},
    {'flag': '🇵🇬', 'code': '+675', 'name': 'Papua New Guinea'},
    {'flag': '🇵🇾', 'code': '+595', 'name': 'Paraguay'},
    {'flag': '🇵🇪', 'code': '+51', 'name': 'Peru'},
    {'flag': '🇵🇭', 'code': '+63', 'name': 'Philippines'},
    {'flag': '🇵🇱', 'code': '+48', 'name': 'Poland'},
    {'flag': '🇵🇹', 'code': '+351', 'name': 'Portugal'},
    {'flag': '🇶🇦', 'code': '+974', 'name': 'Qatar'},
    {'flag': '🇷🇴', 'code': '+40', 'name': 'Romania'},
    {'flag': '🇷🇺', 'code': '+7', 'name': 'Russia'},
    {'flag': '🇷🇼', 'code': '+250', 'name': 'Rwanda'},
    {'flag': '🇰🇳', 'code': '+1-869', 'name': 'Saint Kitts and Nevis'},
    {'flag': '🇱🇨', 'code': '+1-758', 'name': 'Saint Lucia'},
    {
      'flag': '🇻🇨',
      'code': '+1-784',
      'name': 'Saint Vincent and the Grenadines',
    },
    {'flag': '🇼🇸', 'code': '+685', 'name': 'Samoa'},
    {'flag': '🇸🇲', 'code': '+378', 'name': 'San Marino'},
    {'flag': '🇸🇹', 'code': '+239', 'name': 'Sao Tome and Principe'},
    {'flag': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'flag': '🇸🇳', 'code': '+221', 'name': 'Senegal'},
    {'flag': '🇷🇸', 'code': '+381', 'name': 'Serbia'},
    {'flag': '🇸🇨', 'code': '+248', 'name': 'Seychelles'},
    {'flag': '🇸🇱', 'code': '+232', 'name': 'Sierra Leone'},
    {'flag': '🇸🇬', 'code': '+65', 'name': 'Singapore'},
    {'flag': '🇸🇰', 'code': '+421', 'name': 'Slovakia'},
    {'flag': '🇸🇮', 'code': '+386', 'name': 'Slovenia'},
    {'flag': '🇸🇧', 'code': '+677', 'name': 'Solomon Islands'},
    {'flag': '🇸🇴', 'code': '+252', 'name': 'Somalia'},
    {'flag': '🇿🇦', 'code': '+27', 'name': 'South Africa'},
    {'flag': '🇸🇸', 'code': '+211', 'name': 'South Sudan'},
    {'flag': '🇪🇸', 'code': '+34', 'name': 'Spain'},
    {'flag': '🇱🇰', 'code': '+94', 'name': 'Sri Lanka'},
    {'flag': '🇸🇩', 'code': '+249', 'name': 'Sudan'},
    {'flag': '🇸🇷', 'code': '+597', 'name': 'Suriname'},
    {'flag': '🇸🇪', 'code': '+46', 'name': 'Sweden'},
    {'flag': '🇨🇭', 'code': '+41', 'name': 'Switzerland'},
    {'flag': '🇸🇾', 'code': '+963', 'name': 'Syria'},
    {'flag': '🇹🇼', 'code': '+886', 'name': 'Taiwan'},
    {'flag': '🇹🇯', 'code': '+992', 'name': 'Tajikistan'},
    {'flag': '🇹🇿', 'code': '+255', 'name': 'Tanzania'},
    {'flag': '🇹🇭', 'code': '+66', 'name': 'Thailand'},
    {'flag': '🇹🇱', 'code': '+670', 'name': 'Timor-Leste'},
    {'flag': '🇹🇬', 'code': '+228', 'name': 'Togo'},
    {'flag': '🇹🇴', 'code': '+676', 'name': 'Tonga'},
    {'flag': '🇹🇹', 'code': '+1-868', 'name': 'Trinidad and Tobago'},
    {'flag': '🇹🇳', 'code': '+216', 'name': 'Tunisia'},
    {'flag': '🇹🇷', 'code': '+90', 'name': 'Turkey'},
    {'flag': '🇹🇲', 'code': '+993', 'name': 'Turkmenistan'},
    {'flag': '🇹🇻', 'code': '+688', 'name': 'Tuvalu'},
    {'flag': '🇺🇬', 'code': '+256', 'name': 'Uganda'},
    {'flag': '🇺🇦', 'code': '+380', 'name': 'Ukraine'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'United Arab Emirates'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'United States'},
    {'flag': '🇺🇾', 'code': '+598', 'name': 'Uruguay'},
    {'flag': '🇺🇿', 'code': '+998', 'name': 'Uzbekistan'},
    {'flag': '🇻🇺', 'code': '+678', 'name': 'Vanuatu'},
    {'flag': '🇻🇦', 'code': '+39', 'name': 'Vatican City'},
    {'flag': '🇻🇪', 'code': '+58', 'name': 'Venezuela'},
    {'flag': '🇻🇳', 'code': '+84', 'name': 'Vietnam'},
    {'flag': '🇾🇪', 'code': '+967', 'name': 'Yemen'},
    {'flag': '🇿🇲', 'code': '+260', 'name': 'Zambia'},
    {'flag': '🇿🇼', 'code': '+263', 'name': 'Zimbabwe'},
  ];

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        countries: _allCountries,
        onSelected: (code, flag) {
          widget.onSelected(code, flag);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPicker,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.selectedFlag, style: const TextStyle(fontSize: 20)),
            SizedBox(width: 1.w),
            Text(
              widget.selectedCode,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B365D),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final List<Map<String, String>> countries;
  final Function(String code, String flag) onSelected;

  const _CountryPickerSheet({
    required this.countries,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.countries
          : widget.countries
                .where(
                  (c) =>
                      c['name']!.toLowerCase().contains(query) ||
                      c['code']!.contains(query),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75.h,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 1.h),
            width: 10.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Text(
              'Select Country',
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B365D),
              ),
            ),
          ),
          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: GoogleFonts.dmSans(fontSize: 12.sp),
              decoration: InputDecoration(
                hintText: 'Search country or code…',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  color: const Color(0xFF999999),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF999999),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF999999),
                          size: 18,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 1.2.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          const Divider(height: 1),
          // Country list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return ListTile(
                        leading: Text(
                          c['flag']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          c['name']!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          c['code']!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            color: const Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          widget.onSelected(c['code']!, c['flag']!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
