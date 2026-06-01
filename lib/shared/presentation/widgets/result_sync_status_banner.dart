import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';

class ResultSyncStatusBanner extends StatelessWidget {
  const ResultSyncStatusBanner({required this.syncHandle, super.key});

  final BackendResultSyncHandle? syncHandle;

  @override
  Widget build(BuildContext context) {
    final BackendResultSyncHandle? handle = syncHandle;
    if (handle == null) return const SizedBox.shrink();

    return ValueListenableBuilder<BackendSyncStatus>(
      valueListenable: handle.statusListenable,
      builder: (BuildContext context, BackendSyncStatus status, _) {
        final _BannerContent? content = _contentFor(status);
        if (content == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: content.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: content.color.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: <Widget>[
              Icon(content.icon, color: content.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  content.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _BannerContent? _contentFor(BackendSyncStatus status) {
    switch (status.phase) {
      case BackendSyncPhase.idle:
        return null;
      case BackendSyncPhase.syncing:
        return const _BannerContent(
          text: 'Syncing progress…',
          icon: Icons.sync_rounded,
          color: AppColors.accent,
        );
      case BackendSyncPhase.synced:
        final int? xpEarned = status.xpEarned;
        return _BannerContent(
          text: xpEarned == null
              ? 'Progress synced'
              : 'Progress synced · +$xpEarned XP saved',
          icon: Icons.cloud_done_rounded,
          color: AppColors.reward,
        );
      case BackendSyncPhase.alreadySynced:
        return const _BannerContent(
          text: 'Progress synced',
          icon: Icons.cloud_done_rounded,
          color: AppColors.reward,
        );
      case BackendSyncPhase.failed:
        return const _BannerContent(
          text: "Couldn’t sync progress",
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
        );
      case BackendSyncPhase.authRequired:
        return const _BannerContent(
          text: 'Sign in to save progress',
          icon: Icons.lock_rounded,
          color: AppColors.accent,
        );
    }
  }
}

class _BannerContent {
  const _BannerContent({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;
}
