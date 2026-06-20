import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/update_service.dart';
import '../core/theme/app_colors.dart';
import '../services/desktop_integration_service.dart';

Future<void> showUpdateCenter(
  BuildContext context, {
  bool checkImmediately = true,
  UpdateService? service,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !UpdateService.instance.state.stage.isBusy,
    builder: (context) => _UpdateCenterDialog(
      checkImmediately: checkImmediately,
      service: service ?? UpdateService.instance,
    ),
  );
}

class UpdateSettingsPanel extends StatelessWidget {
  final UpdateService? service;

  const UpdateSettingsPanel({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final updater = service ?? UpdateService.instance;
    return AnimatedBuilder(
      animation: updater,
      builder: (context, _) {
        final state = updater.state;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.overlay(context, 0.028),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _UpdateStageIcon(state: state, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.stage.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.statusMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: state.stage.isBusy
                        ? null
                        : () => showUpdateCenter(context),
                    icon: Icon(
                      state.updateAvailable
                          ? Icons.system_update_alt_rounded
                          : Icons.refresh_rounded,
                      size: 17,
                    ),
                    label: Text(state.updateAvailable ? 'Update' : 'Check now'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _UpdateInfoPill(
                    label: 'Current',
                    value: state.currentVersion,
                  ),
                  _UpdateInfoPill(label: 'Latest', value: state.latestVersion),
                  _UpdateInfoPill(label: 'Channel', value: state.channel.label),
                  _UpdateInfoPill(
                    label: 'Platform',
                    value: state.platform.label,
                  ),
                  _UpdateInfoPill(
                    label: 'Package',
                    value: state.packageType.label,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateCenterDialog extends StatefulWidget {
  final bool checkImmediately;
  final UpdateService service;

  const _UpdateCenterDialog({
    required this.checkImmediately,
    required this.service,
  });

  @override
  State<_UpdateCenterDialog> createState() => _UpdateCenterDialogState();
}

class _UpdateCenterDialogState extends State<_UpdateCenterDialog> {
  UpdateService get service => widget.service;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  Future<void> _startIfNeeded() async {
    if (_started || !widget.checkImmediately) return;
    _started = true;
    await service.checkForUpdates();
  }

  Future<void> _install() async {
    await service.performUpdate(
      closeApplication: DesktopIntegrationService.instance.exitHardwareMon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final state = service.state;
        return PopScope(
          canPop: !state.stage.isBusy,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: 680,
              constraints: const BoxConstraints(maxHeight: 720),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 70,
                    offset: const Offset(0, 24),
                  ),
                  BoxShadow(
                    color: _stageColor(state).withValues(alpha: 0.1),
                    blurRadius: 90,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned(
                      top: -150,
                      right: -120,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _stageColor(state).withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, state),
                          const SizedBox(height: 24),
                          _buildProgress(context, state),
                          const SizedBox(height: 20),
                          _buildVersionGrid(context, state),
                          if (state.release != null) ...[
                            const SizedBox(height: 20),
                            _buildReleaseNotes(context, state),
                          ],
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildError(context, state.errorMessage!),
                          ],
                          const SizedBox(height: 24),
                          _buildActions(context, state),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UpdateState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpdateStageIcon(state: state, size: 52),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.stage.label,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  state.statusMessage,
                  key: ValueKey(state.statusMessage),
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!state.stage.isBusy)
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context, UpdateState state) {
    final showBytes =
        state.totalBytes > 0 &&
        (state.stage == UpdateStage.downloading ||
            state.stage == UpdateStage.verifying);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                state.stage.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                showBytes
                    ? '${_formatBytes(state.downloadedBytes)} / '
                          '${_formatBytes(state.totalBytes)}'
                    : '${(state.progress * 100).round()}%',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: AppColors.overlay(context, 0.06),
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _stageColor(state).withValues(alpha: 0.7),
                          _stageColor(state),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _stageColor(state).withValues(alpha: 0.45),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionGrid(BuildContext context, UpdateState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 540
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _UpdateDetailTile(
              width: width,
              icon: Icons.code_rounded,
              label: 'Current version',
              value: state.currentVersion,
            ),
            _UpdateDetailTile(
              width: width,
              icon: Icons.new_releases_outlined,
              label: 'Latest release',
              value: state.latestVersion,
            ),
            _UpdateDetailTile(
              width: width,
              icon: Icons.alt_route_rounded,
              label: 'Build channel',
              value: state.channel.label,
            ),
            _UpdateDetailTile(
              width: width,
              icon: Icons.inventory_2_outlined,
              label: 'Platform and package',
              value: '${state.platform.label} · ${state.packageType.label}',
            ),
          ],
        );
      },
    );
  }

  Widget _buildReleaseNotes(BuildContext context, UpdateState state) {
    final release = state.release!;
    final published = release.publishedAt == null
        ? null
        : DateFormat.yMMMd().add_Hm().format(release.publishedAt!.toLocal());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 17),
              const SizedBox(width: 8),
              const Text(
                'Release notes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (published != null) ...[
                const Spacer(),
                Text(
                  published,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            release.notes.isEmpty
                ? 'No release notes were provided.'
                : release.notes,
            maxLines: 7,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, UpdateState state) {
    if (state.stage == UpdateStage.downloading) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: service.cancelDownload,
          icon: const Icon(Icons.close_rounded, size: 17),
          label: const Text('Cancel download'),
        ),
      );
    }
    if (state.stage.isBusy) {
      return Text(
        state.stage == UpdateStage.restarting
            ? 'Do not close the installer permission prompt.'
            : 'Please keep HardwareMon open while this stage completes.',
        style: TextStyle(color: AppColors.textMuted(context), fontSize: 11),
      );
    }

    return Row(
      children: [
        if (state.release != null)
          TextButton.icon(
            onPressed: service.openReleasePage,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Release page'),
          ),
        const Spacer(),
        if (state.stage == UpdateStage.failed)
          OutlinedButton.icon(
            onPressed: service.checkForUpdates,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Try again'),
          ),
        if (state.stage == UpdateStage.failed) const SizedBox(width: 10),
        if (state.canInstallAutomatically)
          FilledButton.icon(
            onPressed: _install,
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: const Text('Update now'),
          )
        else if (state.updateAvailable)
          FilledButton.icon(
            onPressed: service.openReleasePage,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Manual update'),
          )
        else if (state.stage == UpdateStage.complete)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          )
        else
          FilledButton.icon(
            onPressed: service.checkForUpdates,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Check again'),
          ),
      ],
    );
  }
}

class _UpdateStageIcon extends StatelessWidget {
  final UpdateState state;
  final double size;

  const _UpdateStageIcon({required this.state, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(state);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.31),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 22),
        ],
      ),
      child: state.stage.isBusy
          ? Padding(
              padding: EdgeInsets.all(size * 0.29),
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(_stageIcon(state.stage), color: color, size: size * 0.47),
    );
  }
}

class _UpdateInfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _UpdateInfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDetailTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _UpdateDetailTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.028),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _stageColor(UpdateState state) {
  return switch (state.stage) {
    UpdateStage.failed => Colors.redAccent,
    UpdateStage.complete => Colors.greenAccent,
    UpdateStage.available => Colors.cyanAccent,
    UpdateStage.installing || UpdateStage.restarting => Colors.orangeAccent,
    _ => AppColors.accent,
  };
}

IconData _stageIcon(UpdateStage stage) {
  return switch (stage) {
    UpdateStage.available => Icons.system_update_alt_rounded,
    UpdateStage.complete => Icons.check_rounded,
    UpdateStage.failed => Icons.error_outline_rounded,
    UpdateStage.installing => Icons.install_desktop_rounded,
    UpdateStage.restarting => Icons.restart_alt_rounded,
    _ => Icons.update_rounded,
  };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
