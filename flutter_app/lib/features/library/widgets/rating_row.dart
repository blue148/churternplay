import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The two personal ratings a game can carry.
enum RatingKind {
  hearts('Likes', 'hearts', Icons.favorite, Icons.favorite_border,
      AppColors.clay400),
  fists('Punch-worthy', 'fists', Icons.sports_mma, Icons.sports_mma_outlined,
      AppColors.plum400);

  const RatingKind(
      this.label, this.unit, this.filledIcon, this.emptyIcon, this.color);

  final String label;
  final String unit;
  final IconData filledIcon;
  final IconData emptyIcon;
  final Color color;
}

/// Five tappable icons (0–5). Tapping the current value clears it back to 0.
/// Pass a null [onChanged] for a compact read-only display.
class RatingRow extends StatelessWidget {
  const RatingRow({
    super.key,
    required this.kind,
    required this.value,
    this.onChanged,
    this.showLabel = true,
    this.iconSize = 28,
  });

  final RatingKind kind;
  final int value;
  final ValueChanged<int>? onChanged;
  final bool showLabel;
  final double iconSize;

  bool get _editable => onChanged != null;

  void _set(int next) => onChanged?.call(next == value ? 0 : next);

  @override
  Widget build(BuildContext context) {
    final summary = '${kind.label}, $value of 5 ${kind.unit}';
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          _editable
              ? InkResponse(
                  onTap: () => _set(i),
                  radius: 24,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      i <= value ? kind.filledIcon : kind.emptyIcon,
                      size: iconSize,
                      color: i <= value ? kind.color : AppColors.ink200,
                    ),
                  ),
                )
              : Icon(
                  i <= value ? kind.filledIcon : kind.emptyIcon,
                  size: iconSize,
                  color: i <= value ? kind.color : AppColors.ink100,
                ),
      ],
    );

    return Semantics(
      container: true,
      label: summary,
      value: _editable ? '$value' : null,
      increasedValue: _editable && value < 5 ? '${value + 1}' : null,
      decreasedValue: _editable && value > 0 ? '${value - 1}' : null,
      onIncrease: _editable && value < 5 ? () => onChanged!(value + 1) : null,
      onDecrease: _editable && value > 0 ? () => onChanged!(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              SizedBox(
                width: 104,
                child: Text(kind.label,
                    style: AppTextStyles.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.ink400)),
              ),
            ],
            icons,
          ],
        ),
      ),
    );
  }
}

/// Compact read-only "♥ 3  🥊 2" summary for cards and list rows. Renders
/// nothing when neither rating is set.
class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.hearts, required this.fists});

  final int hearts;
  final int fists;

  @override
  Widget build(BuildContext context) {
    if (hearts == 0 && fists == 0) return const SizedBox.shrink();
    Widget part(RatingKind k, int v) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(k.filledIcon, size: 14, color: k.color),
            const SizedBox(width: 2),
            Text('$v',
                style: AppTextStyles.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.ink400)),
          ],
        );
    return Semantics(
      label: 'Hearts $hearts of 5, fists $fists of 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hearts > 0) part(RatingKind.hearts, hearts),
            if (hearts > 0 && fists > 0) const SizedBox(width: 8),
            if (fists > 0) part(RatingKind.fists, fists),
          ],
        ),
      ),
    );
  }
}
