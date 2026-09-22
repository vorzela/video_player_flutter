import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidVorzelaPlayerControllerInBuild extends DartLintRule {
  const AvoidVorzelaPlayerControllerInBuild() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_vorzela_player_controller_in_build',
    problemMessage:
        'Do not construct VorzelaPlayerController inside Widget build.',
    correctionMessage:
        'Create the controller in initState or hold it above build (e.g. parent State).',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addInstanceCreationExpression((node) {
      if (!isInsideWidgetBuild(node)) return;
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'VorzelaPlayerController') return;
      reporter.atNode(node.constructorName, code);
    });
  }
}
