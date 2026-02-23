import 'package:flutter/material.dart';

class OnboardingStepScaffold extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
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
    required this.onSkip,
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
        leading: currentPage > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
        actions: [
          TextButton(
            onPressed: onSkip,
            child: const Text('Saltar'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
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
                        : scheme.outline.withOpacity(0.3),
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