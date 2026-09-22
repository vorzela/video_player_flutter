import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidHttpHlsLoad extends DartLintRule {
  const AvoidHttpHlsLoad() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_http_hls_load',
    problemMessage: 'Avoid loading HLS over plain http:// — use https:// instead.',
    correctionMessage: 'Use an https:// URL for load().',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'load') return;
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;
      final first = args.first;
      if (first is! StringLiteral) return;
      final value = first.stringValue;
      if (value == null) return;
      if (value.startsWith('http://')) {
        reporter.atNode(first, code);
      }
    });
  }
}
