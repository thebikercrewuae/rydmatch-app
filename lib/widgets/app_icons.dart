import 'package:flutter/material.dart';

/// Typed icon constants — single source of truth for the whole app.
/// All icons use the _rounded variant for a modern, cohesive look.
class AppIcons {
  // ── Navigation / Actions
  static const IconData arrowBack = Icons.arrow_back_rounded;
  static const IconData arrowBackIos = Icons.arrow_back_ios_new_rounded;
  static const IconData arrowForwardIos = Icons.arrow_forward_ios_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData moreVert = Icons.more_vert_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData tune = Icons.tune_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData copy = Icons.content_copy_rounded;
  static const IconData flag = Icons.flag_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData radioUnchecked = Icons.radio_button_unchecked_rounded;

  // ── Brand / Moto
  static const IconData moto = Icons.sports_motorsports_rounded;
  static const IconData twoWheeler = Icons.two_wheeler_rounded;
  static const IconData motorcycle = Icons.motorcycle_rounded;
  static const IconData directionsBike = Icons.directions_bike_rounded;
  static const IconData garage = Icons.garage_rounded;
  static const IconData speed = Icons.speed_rounded;

  // ── Social / Matching
  static const IconData favorite = Icons.favorite_rounded;
  static const IconData favoriteBorder = Icons.favorite_border_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData starOutline = Icons.star_border_rounded;
  static const IconData verified = Icons.verified_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData group = Icons.group_rounded;
  static const IconData person = Icons.person_rounded;
  static const IconData personOutline = Icons.person_outline_rounded;

  // ── Location / Map
  static const IconData locationOn = Icons.location_on_rounded;
  static const IconData locationOutlined = Icons.location_on_rounded;
  static const IconData locationOff = Icons.location_off_rounded;
  static const IconData myLocation = Icons.my_location_rounded;
  static const IconData map = Icons.map_rounded;
  static const IconData route = Icons.route_rounded;
  static const IconData explore = Icons.explore_rounded;
  static const IconData terrain = Icons.terrain_rounded;

  // ── UI / Misc
  static const IconData settings = Icons.settings_rounded;
  static const IconData settingsOutlined = Icons.settings_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData lockOutline = Icons.lock_outline_rounded;
  static const IconData email = Icons.email_rounded;
  static const IconData emailOutlined = Icons.email_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData infoOutline = Icons.info_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData errorOutline = Icons.error_outline_rounded;
  static const IconData help = Icons.help_rounded;
  static const IconData description = Icons.description_rounded;
  static const IconData privacyTip = Icons.privacy_tip_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData notification = Icons.notifications_rounded;
  static const IconData notificationOutlined = Icons.notifications_rounded;
  static const IconData chatBubble = Icons.chat_bubble_rounded;
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline_rounded;
  static const IconData camera = Icons.camera_alt_rounded;
  static const IconData cameraOutlined = Icons.camera_alt_rounded;
  static const IconData photoLibrary = Icons.photo_library_rounded;
  static const IconData addPhoto = Icons.add_photo_alternate_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData timer = Icons.timer_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData analytics = Icons.analytics_rounded;
  static const IconData barChart = Icons.bar_chart_rounded;
  static const IconData trendingUp = Icons.trending_up_rounded;
  static const IconData premium = Icons.workspace_premium_rounded;
  static const IconData rocket = Icons.rocket_launch_rounded;
  static const IconData fire = Icons.local_fire_department_rounded;
  static const IconData trophy = Icons.emoji_events_rounded;
  static const IconData build = Icons.build_rounded;
  static const IconData straighten = Icons.straighten_rounded;
  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData darkMode = Icons.dark_mode_rounded;
  static const IconData phoneAndroid = Icons.phone_android_rounded;
  static const IconData pdf = Icons.picture_as_pdf_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData iosShare = Icons.ios_share_rounded;
  static const IconData brokenImage = Icons.broken_image_rounded;
  static const IconData language = Icons.language_rounded;
  static const IconData localCafe = Icons.local_cafe_rounded;
  static const IconData militaryTech = Icons.military_tech_rounded;
  static const IconData apple = Icons.apple_rounded;
  static const IconData gMobiledata = Icons.g_mobiledata_rounded;

  /// Resolves a legacy string icon name to an [IconData].
  static IconData fromName(String name) {
    final iconMap = <String, IconData>{
      'arrow_back': arrowBack,
      'arrow_back_ios_new': arrowBackIos,
      'arrow_forward_ios': arrowForwardIos,
      'chevron_right': chevronRight,
      'close': close,
      'add': add,
      'edit': edit,
      'delete': delete,
      'more_vert': moreVert,
      'send': send,
      'search': search,
      'tune': tune,
      'share': share,
      'copy': copy,
      'copy_outlined': copy,
      'flag': flag,
      'check': check,
      'check_circle': checkCircle,
      'two_wheeler': twoWheeler,
      'motorcycle': motorcycle,
      'directions_bike': directionsBike,
      'garage': garage,
      'speed': speed,
      'favorite': favorite,
      'favorite_border': favoriteBorder,
      'star': star,
      'star_outline': starOutline,
      'verified': verified,
      'bolt': bolt,
      'group': group,
      'person': person,
      'location_on': locationOn,
      'my_location': myLocation,
      'map': map,
      'route': route,
      'explore': explore,
      'terrain': terrain,
      'settings': settings,
      'settings_outlined': settingsOutlined,
      'lock_outline': lockOutline,
      'email_outlined': emailOutlined,
      'visibility': visibility,
      'visibility_outlined': visibility,
      'visibility_off_outlined': visibilityOff,
      'info_outline': infoOutline,
      'error_outline': errorOutline,
      'help_outline': help,
      'description_outlined': description,
      'privacy_tip_outlined': privacyTip,
      'logout': logout,
      'chat_bubble_outline': chatBubbleOutline,
      'camera_alt': camera,
      'photo_library': photoLibrary,
      'add_photo_alternate_outlined': addPhoto,
      'schedule': schedule,
      'timer_outlined': timer,
      'calendar_today': calendar,
      'analytics': analytics,
      'bar_chart': barChart,
      'trending_up': trendingUp,
      'workspace_premium': premium,
      'rocket_launch': rocket,
      'local_fire_department': fire,
      'emoji_events': trophy,
      'build_outlined': build,
      'straighten': straighten,
      'local_cafe': localCafe,
      'military_tech': militaryTech,
    };
    return iconMap[name] ?? Icons.circle_rounded;
  }
}
