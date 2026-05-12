import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class MatchCategoryTabWidget extends StatelessWidget {
  final TabController tabController;
  final List<String> tabs;

  const MatchCategoryTabWidget({
    super.key,
    required this.tabController,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TabBar(
      controller: tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelPadding: EdgeInsets.symmetric(horizontal: 3.w),
      tabs: tabs.map((tab) => Tab(text: tab)).toList(),
      labelStyle: theme.tabBarTheme.labelStyle,
      unselectedLabelStyle: theme.tabBarTheme.unselectedLabelStyle,
      labelColor: theme.tabBarTheme.labelColor,
      unselectedLabelColor: theme.tabBarTheme.unselectedLabelColor,
      indicatorColor: theme.tabBarTheme.indicatorColor,
    );
  }
}
