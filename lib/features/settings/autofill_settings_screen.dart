import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AutofillSettingsScreen extends StatelessWidget {
  const AutofillSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autofill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.textHint,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text('Autofill — Coming Soon', style: AppTextStyles.titleLarge),
              const SizedBox(height: 10),
              Text(
                'Autofill support is under development. Once enabled, CredLock will automatically fill your credentials in apps and websites.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
