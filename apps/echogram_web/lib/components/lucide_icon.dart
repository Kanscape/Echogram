import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

part 'lucide_icon.g.dart';

/// Inline Lucide SVGs sourced from lucide-static and generated on demand.
///
/// Add icons by name, for example `LucideIcon('<name>')`, then run one of:
/// - `npm run generate:icons`
/// - `npm run build:css`
/// - `npm run watch:css`
class LucideIcon extends StatelessComponent {
  const LucideIcon(
    this.name, {
    this.classes,
    this.size = 18,
    this.strokeWidth = 2,
    super.key,
  });

  final String name;
  final String? classes;
  final num size;
  final num strokeWidth;

  @override
  Component build(BuildContext context) {
    final mergedClasses = ['lucide-icon', if (classes != null && classes!.isNotEmpty) classes!].join(' ');
    final children = _buildLucideNodes(name) ?? _fallbackLucideNodes();

    return svg(
      children,
      classes: mergedClasses,
      width: size.px,
      height: size.px,
      viewBox: '0 0 24 24',
      attributes: {
        'fill': 'none',
        'stroke': 'currentColor',
        'stroke-width': '$strokeWidth',
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
        'aria-hidden': 'true',
        'focusable': 'false',
      },
    );
  }

  List<Component> _fallbackLucideNodes() {
    return [
      rect(x: '3', y: '3', width: '18', height: '18', rx: '2', []),
      path(d: 'm9 9 6 6', []),
      path(d: 'm15 9-6 6', []),
    ];
  }
}
