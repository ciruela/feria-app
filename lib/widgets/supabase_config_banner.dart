import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Aviso visible cuando la app se compiló sin credenciales de Supabase.
class SupabaseConfigBanner extends StatelessWidget {
  const SupabaseConfigBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.useSupabase) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo local — Supabase NO configurado',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Esta build se instaló sin credenciales. Los cambios quedan solo '
            'en este dispositivo. Reinstalá con:\n'
            './scripts/install_ios_device.sh',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
