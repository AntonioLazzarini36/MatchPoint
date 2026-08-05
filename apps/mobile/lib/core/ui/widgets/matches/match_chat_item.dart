import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/sport_words.dart';
import 'package:match_point/features/discovery/models/sport.dart';

class MatchChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String? imageUrl;
  final bool unread;

  /// Deporte del match. Con los dos deportes mezclados en la misma lista,
  /// el nombre solo no dice si esa conversacion es de tenis o de correr —
  /// y eso cambia lo que vas a proponerle.
  final Sport? sport;

  final bool isGroup;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MatchChatItem({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.imageUrl,
    required this.unread,
    this.sport,
    this.isGroup = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: imageUrl != null
                  ? NetworkImage(imageUrl!)
                  : null,
              backgroundColor: context.colors.primaryContainer,
              child: imageUrl == null
                  ? Icon(
                      isGroup ? Icons.groups : Icons.person,
                      color: context.colors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: context.textStyles.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sport != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                sportIcon(sport!),
                                size: 15,
                                color: context.colors.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: unread
                        ? context.textStyles.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          )
                        : context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
