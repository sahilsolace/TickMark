import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_colors.dart';

class CustomHeaderBar extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onExportCsv;
  final VoidCallback onMinimizeToMini;

  const CustomHeaderBar({
    super.key,
    required this.onOpenSettings,
    required this.onExportCsv,
    required this.onMinimizeToMini,
  });

  @override
  State<CustomHeaderBar> createState() => _CustomHeaderBarState();
}

class _CustomHeaderBarState extends State<CustomHeaderBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted && max != _isMaximized) {
        setState(() => _isMaximized = max);
      }
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
        setState(() => _isMaximized = false);
      } else {
        await windowManager.maximize();
        setState(() => _isMaximized = true);
      }
    } catch (e) {
      debugPrint('Error toggling maximize: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Drag to move window area covering the brand section
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // App Logo Icon
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // App Title
                    Row(
                      children: [
                        const Text(
                          'TickMark',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreenLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DESKTOP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          // Header Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Export CSV Button
                FilledButton.icon(
                  onPressed: widget.onExportCsv,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 15),
                  label: const Text(
                    'Export CSV',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),

                // Settings Button
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary),
                  onPressed: widget.onOpenSettings,
                  style: IconButton.styleFrom(
                    hoverColor: AppColors.primaryGreenLight,
                    visualDensity: VisualDensity.compact,
                  ),
                ),

                // Mini Mode Widget Toggle Button
                IconButton(
                  tooltip: 'Mini Tracker (Ongoing Task Only)',
                  icon: const Icon(Icons.branding_watermark_outlined, size: 18, color: AppColors.primaryGreen),
                  onPressed: widget.onMinimizeToMini,
                  style: IconButton.styleFrom(
                    hoverColor: AppColors.primaryGreenLight,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 2),

                // Window Minimize (Minimizes to ongoing task widget)
                IconButton(
                  tooltip: 'Minimize to Ongoing Task',
                  icon: const Icon(Icons.remove, size: 18, color: AppColors.textSecondary),
                  onPressed: widget.onMinimizeToMini,
                  visualDensity: VisualDensity.compact,
                ),

                // Window Maximize / Restore
                IconButton(
                  tooltip: _isMaximized ? 'Restore' : 'Maximize',
                  icon: Icon(
                    _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: _toggleMaximize,
                  visualDensity: VisualDensity.compact,
                ),

                // Window Close
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  hoverColor: AppColors.deleteBg,
                  onPressed: () async {
                    await windowManager.close();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
