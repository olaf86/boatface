import 'package:flutter/material.dart';

class RacerNameText extends StatelessWidget {
  const RacerNameText({
    required this.name,
    this.nameKana,
    this.style,
    this.kanaStyle,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final String name;
  final String? nameKana;
  final TextStyle? style;
  final TextStyle? kanaStyle;
  final TextAlign textAlign;

  bool get _hasKana => nameKana != null && nameKana!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle effectiveStyle = style ?? textTheme.titleMedium!;
    final TextStyle effectiveKanaStyle =
        kanaStyle ??
        textTheme.labelMedium!.copyWith(
          fontSize: (effectiveStyle.fontSize ?? 16) * 0.58,
          height: 1,
          color: effectiveStyle.color?.withValues(alpha: 0.82),
        );

    if (!_hasKana) {
      return Text(name, style: effectiveStyle, textAlign: textAlign);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (textAlign) {
        TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: <Widget>[
        Text(nameKana!, style: effectiveKanaStyle, textAlign: textAlign),
        const SizedBox(height: 1),
        Text(name, style: effectiveStyle, textAlign: textAlign),
      ],
    );
  }
}
