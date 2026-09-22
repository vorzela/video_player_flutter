import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferDisposeVorzelaPlayerController extends DartLintRule {
  const PreferDisposeVorzelaPlayerController() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_dispose_vorzela_player_controller',
    problemMessage:
        'State holds VorzelaPlayerController but dispose() does not release it.',
    correctionMessage:
        'Call controller.dispose() or await controller.disposePlayer() in dispose().',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addClassDeclaration((node) {
      if (!isStateClass(node)) return;
      final fields = _controllerFieldNames(node);
      if (fields.isEmpty) return;
      final disposeMethod = _findDisposeMethod(node);
      for (final field in fields) {
        if (!_disposeReleasesField(disposeMethod, field)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  List<String> _controllerFieldNames(ClassDeclaration cls) {
    final names = <String>[];
    for (final member in cls.members) {
      if (member is! FieldDeclaration) continue;
      for (final variable in member.fields.variables) {
        final type = member.fields.type?.toSource() ?? '';
        if (isVorzelaPlayerControllerType(type)) {
          names.add(variable.name.lexeme);
        }
      }
    }
    return names;
  }

  MethodDeclaration? _findDisposeMethod(ClassDeclaration cls) {
    for (final member in cls.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'dispose' &&
          !member.isGetter &&
          !member.isSetter) {
        return member;
      }
    }
    return null;
  }

  bool _disposeReleasesField(MethodDeclaration? dispose, String fieldName) {
    if (dispose == null || dispose.body == null) return false;
    var found = false;
    dispose.body!.visitChildren(_DisposeVisitor(fieldName, () => found = true));
    return found;
  }
}

class _DisposeVisitor extends RecursiveAstVisitor<void> {
  _DisposeVisitor(this.fieldName, this.onMatch);

  final String fieldName;
  final void Function() onMatch;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final method = node.methodName.name;
    if (method == 'dispose' || method == 'disposePlayer') {
      if (target is SimpleIdentifier && target.name == fieldName) {
        onMatch();
      }
      if (target is PrefixedIdentifier &&
          target.identifier.name == fieldName &&
          (method == 'dispose' || method == 'disposePlayer')) {
        onMatch();
      }
    }
    super.visitMethodInvocation(node);
  }
}
