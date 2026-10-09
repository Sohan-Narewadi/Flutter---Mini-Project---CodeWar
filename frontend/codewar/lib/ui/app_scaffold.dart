import 'package:flutter/material.dart';

import '../utils/theme.dart';
import 'arcade_backdrop.dart';

/// Page scaffold: arcade backdrop, safe area, content centred at a readable
/// max width on wide screens. [bottom] is typically the bottom nav bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottom,
    this.maxWidth = AppSpace.maxContentWidth,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final double maxWidth;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: false,
      appBar: appBar,
      body: ArcadeBackdrop(
        child: SafeArea(
          bottom: bottom == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: bottom,
              ),
            ),
    );
  }
}

/// Standard page header used on tab screens: big display title with an
/// optional subtitle and trailing action.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.display(fontSize: 30, height: 1.1)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
