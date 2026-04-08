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
          fontSize: (effectiveStyle.fontSize ?? 16) * 0.32,
          height: 0.72,
          color: effectiveStyle.color?.withValues(alpha: 0.9),
        );
    final List<String> nameParts = _splitName(name);
    final List<String> kanaParts = _hasKana
        ? _splitName(nameKana!)
        : <String>[];

    if (!_hasKana) {
      return Text(name, style: effectiveStyle, textAlign: textAlign);
    }

    if (nameParts.length != 2 || kanaParts.length != 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _crossAxisAlignmentFor(textAlign),
        children: <Widget>[
          Text(nameKana!, style: effectiveKanaStyle, textAlign: textAlign),
          Text(
            name,
            style: effectiveStyle.copyWith(height: 0.92),
            textAlign: textAlign,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAxisAlignmentFor(textAlign),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: _rowMainAxisAlignmentFor(textAlign),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RacerNamePart(
              name: nameParts[0],
              nameKana: kanaParts[0],
              style: effectiveStyle,
              kanaStyle: effectiveKanaStyle,
              textAlign: textAlign,
            ),
            const SizedBox(width: 6),
            _RacerNamePart(
              name: nameParts[1],
              nameKana: kanaParts[1],
              style: effectiveStyle,
              kanaStyle: effectiveKanaStyle,
              textAlign: textAlign,
            ),
          ],
        ),
      ],
    );
  }
}

class _RacerNamePart extends StatelessWidget {
  const _RacerNamePart({
    required this.name,
    required this.nameKana,
    required this.style,
    required this.kanaStyle,
    required this.textAlign,
  });

  final String name;
  final String nameKana;
  final TextStyle style;
  final TextStyle kanaStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(nameKana, style: kanaStyle, textAlign: textAlign),
        const SizedBox(height: 4),
        Text(name, style: style.copyWith(height: 0.92), textAlign: textAlign),
      ],
    );
  }
}

List<String> _splitName(String value) {
  return value
      .trim()
      .split(RegExp(r'[\s　]+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}

CrossAxisAlignment _crossAxisAlignmentFor(TextAlign textAlign) {
  return switch (textAlign) {
    TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
    TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.center,
  };
}

MainAxisAlignment _rowMainAxisAlignmentFor(TextAlign textAlign) {
  return switch (textAlign) {
    TextAlign.left || TextAlign.start => MainAxisAlignment.start,
    TextAlign.right || TextAlign.end => MainAxisAlignment.end,
    _ => MainAxisAlignment.center,
  };
}
