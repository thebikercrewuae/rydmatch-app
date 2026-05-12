import 'package:flutter/material.dart';

/// Stub implementation for web — dart:io is not available on web.
/// This file is imported when dart.library.io is NOT available.
Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
  Color? color,
  String? semanticLabel,
}) {
  // Web does not support file:// image paths — return empty box
  return SizedBox(height: height, width: width);
}
