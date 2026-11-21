import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'rating_row.dart';

/// Bottom sheet to set a game's hearts and fists. Keeps its own copy of the
/// values so the icons respond instantly; [onHearts]/[onPunch] persist them.
Future<void> showRatingSheet({
  required BuildContext context,
  required String gameName,
  required int hearts,
  required int fists,
  required ValueChanged<int> onHearts,
  required ValueChanged<int> onPunch,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.parchment50,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RatingSheet(
      gameName: gameName,
      hearts: hearts,
      fists: fists,
      onHearts: onHearts,
      onPunch: onPunch,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({
    required this.gameName,
    required this.hearts,
    required this.fists,
    required this.onHearts,
    required this.onPunch,
  });

  final String gameName;
  final int hearts;
  final int fists;
  final ValueChanged<int> onHearts;
  final ValueChanged<int> onPunch;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _hearts = widget.hearts;
  late int _fists = widget.fists;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate ${widget.gameName}',
                style: AppTextStyles.display(size: 20, weight: FontWeight.w400)
                    .copyWith(color: AppColors.ink500)),
            const SizedBox(height: 4),
            Text('Tap the current rating again to clear it.',
                style: AppTextStyles.body(size: 12, color: AppColors.ink300)),
            const SizedBox(height: 12),
            RatingRow(
              kind: RatingKind.hearts,
              value: _hearts,
              onChanged: (v) {
                setState(() => _hearts = v);
                widget.onHearts(v);
              },
            ),
            RatingRow(
              kind: RatingKind.fists,
              value: _fists,
              onChanged: (v) {
                setState(() => _fists = v);
                widget.onPunch(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
