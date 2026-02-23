import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

class MatchesSectionTitle extends StatelessWidget {
  final String title;
  const MatchesSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textStyles.titleLarge?.copyWith(
        color: context.colors.primary,
      ),
    );
  }
}