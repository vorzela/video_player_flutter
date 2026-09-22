import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidHoverPreviewPerListItem extends DartLintRule {
  const AvoidHoverPreviewPerListItem() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hover_preview_per_list_item',
    problemMessage:
        'Do not create VorzelaHoverPreview inside list itemBuilder — use a shared session or one preview.',
    correctionMessage:
        'Hoist preview state above the list or use VorzelaPreviewSession.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'VorzelaHoverPreview') return;
      if (!isInsideListItemBuilder(node)) return;
      reporter.atNode(node.constructorName, code);
    });
  }
}
