import 'package:analyzer/dart/ast/ast.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

bool isTestPath(CustomLintResolver resolver) {
  final path = resolver.source.fullName.replaceAll(r'\', '/');
  return path.contains('/test/') || path.endsWith('_test.dart');
}

/// True when [node] is inside a Widget `build` method.
bool isInsideWidgetBuild(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is MethodDeclaration && current.name.lexeme == 'build') {
      return _enclosingClassLooksLikeWidget(current);
    }
    current = current.parent;
  }
  return false;
}

bool _enclosingClassLooksLikeWidget(MethodDeclaration method) {
  final parent = method.thisOrAncestorOfType<ClassDeclaration>();
  if (parent == null) return false;
  final name = parent.name.lexeme;
  if (name.endsWith('Widget') ||
      name.endsWith('State') ||
      name.endsWith('Page') ||
      name.endsWith('Screen') ||
      name.endsWith('View')) {
    return true;
  }
  final extendsClause = parent.extendsClause;
  if (extendsClause == null) return false;
  final superName = extendsClause.superclass.name.lexeme;
  return superName.contains('StatelessWidget') ||
      superName.contains('StatefulWidget') ||
      superName.contains('State') ||
      superName.contains('ConsumerWidget') ||
      superName.contains('HookWidget');
}

bool isStateClass(ClassDeclaration cls) {
  final extendsClause = cls.extendsClause;
  if (extendsClause == null) return false;
  final superType = extendsClause.superclass.element?.displayName ??
      extendsClause.superclass.toSource();
  return superType.contains('State<') || superType.endsWith('State');
}

bool isVorzelaPlayerControllerType(String typeSource) {
  return typeSource == 'VorzelaPlayerController' ||
      typeSource.startsWith('VorzelaPlayerController');
}

bool isInsideListItemBuilder(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is FunctionExpression) {
      final parent = current.parent;
      if (parent is NamedExpression) {
        final paramName = parent.name.label.name;
        if (paramName == 'itemBuilder' || paramName == 'builder') {
          if (_namedArgBelongsToListLike(parent)) return true;
        }
      }
    }
    current = current.parent;
  }
  return false;
}

bool _namedArgBelongsToListLike(NamedExpression named) {
  final args = named.parent;
  if (args is! ArgumentList) return false;
  final invocOrCreate = args.parent;
  if (invocOrCreate is InstanceCreationExpression) {
    return _isListLikeType(invocOrCreate.constructorName.type.toSource());
  }
  return false;
}

bool _isListLikeType(String typeSource) {
  return typeSource.contains('ListView') ||
      typeSource.contains('GridView') ||
      typeSource.contains('SliverList') ||
      typeSource.contains('SliverGrid');
}
