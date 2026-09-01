import 'package:flutter/material.dart';
import 'package:match_point/core/i18n/app_locale.dart';

class OnboardingStepScaffold extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onNext;
  final bool isLoading;
  final String nextLabel;
  final Widget child;
  final String? errorText;

  const OnboardingStepScaffold({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onBack,
    this.onSkip,
    required this.onNext,
    required this.isLoading,
    required this.nextLabel,
    required this.child,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // Antes se ocultaba en la primera página (no había "atrás" al
        // que ir); ahora la primera página también tiene una acción de
        // "atrás" válida — salir del wizard — así que solo se oculta si
        // el padre no pasó ningún `onBack` en absoluto.
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        actions: onSkip == null
            ? const []
            : [TextButton(onPressed: onSkip, child: Text(S.current.skip))],
      ),
      body: Column(
        children: [
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // indicators
            Row(
              children: List.generate(totalPages, (index) {
                final isActive = currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            ElevatedButton(
              onPressed: isLoading ? null : onNext,
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(nextLabel),
            ),
          ],
        ),
      ),
    );
  }
}
