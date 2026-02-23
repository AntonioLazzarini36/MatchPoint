import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

class NewMatchAvatarItem extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;

  const NewMatchAvatarItem({
    super.key,
    required this.name,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.primary, width: 2),
              image: imageUrl != null
                  ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                  : null,
              color: imageUrl == null ? context.colors.primaryContainer : null,
            ),
            child: imageUrl == null
                ? Icon(Icons.person, color: context.colors.primary)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 74,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.textStyles.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}