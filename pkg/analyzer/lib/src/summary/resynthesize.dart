// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library summary_resynthesizer;

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/element_handle.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/testing/ast_factory.dart';
import 'package:analyzer/src/generated/testing/token_factory.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'package:analyzer/src/summary/format.dart';

/**
 * Implementation of [ElementResynthesizer] used when resynthesizing an element
 * model from summaries.
 */
abstract class SummaryResynthesizer extends ElementResynthesizer {
  /**
   * The parent [SummaryResynthesizer] which is asked to resynthesize elements
   * and get summaries before this resynthesizer attempts to do this.
   * Can be `null`.
   */
  final SummaryResynthesizer parent;

  /**
   * Source factory used to convert URIs to [Source] objects.
   */
  final SourceFactory sourceFactory;

  /**
   * Cache of [Source] objects that have already been converted from URIs.
   */
  final Map<String, Source> _sources = <String, Source>{};

  /**
   * The [TypeProvider] used to obtain core types (such as Object, int, List,
   * and dynamic) during resynthesis.
   */
  final TypeProvider typeProvider;

  /**
   * Indicates whether the summary should be resynthesized assuming strong mode
   * semantics.
   */
  final bool strongMode;

  /**
   * Map of top level elements resynthesized from summaries.  The three map
   * keys are the first three elements of the element's location (the library
   * URI, the compilation unit URI, and the name of the top level declaration).
   */
  final Map<String, Map<String, Map<String, Element>>> _resynthesizedElements =
      <String, Map<String, Map<String, Element>>>{};

  /**
   * Map of libraries which have been resynthesized from summaries.  The map
   * key is the library URI.
   */
  final Map<String, LibraryElement> _resynthesizedLibraries =
      <String, LibraryElement>{};

  SummaryResynthesizer(this.parent, AnalysisContext context, this.typeProvider,
      this.sourceFactory, this.strongMode)
      : super(context);

  /**
   * Number of libraries that have been resynthesized so far.
   */
  int get resynthesisCount => _resynthesizedLibraries.length;

  /**
   * Perform delayed finalization of the `dart:core` and `dart:async` libraries.
   */
  void finalizeCoreAsyncLibraries() {
    (_resynthesizedLibraries['dart:core'] as LibraryElementImpl)
        .createLoadLibraryFunction(typeProvider);
    (_resynthesizedLibraries['dart:async'] as LibraryElementImpl)
        .createLoadLibraryFunction(typeProvider);
  }

  @override
  Element getElement(ElementLocation location) {
    List<String> components = location.components;
    String libraryUri = components[0];
    // Ask the parent resynthesizer.
    if (parent != null && parent._hasLibrarySummary(libraryUri)) {
      return parent.getElement(location);
    }
    // Resynthesize locally.
    if (components.length == 1) {
      return getLibraryElement(libraryUri);
    } else if (components.length == 3 || components.length == 4) {
      Map<String, Map<String, Element>> libraryMap =
          _resynthesizedElements[libraryUri];
      if (libraryMap == null) {
        getLibraryElement(libraryUri);
        libraryMap = _resynthesizedElements[libraryUri];
        assert(libraryMap != null);
      }
      Map<String, Element> compilationUnitElements = libraryMap[components[1]];
      Element element;
      if (compilationUnitElements != null) {
        element = compilationUnitElements[components[2]];
      }
      if (element != null && components.length == 4) {
        String name = components[3];
        Element parentElement = element;
        if (parentElement is ClassElement) {
          if (name.endsWith('?')) {
            element =
                parentElement.getGetter(name.substring(0, name.length - 1));
          } else if (name.endsWith('=')) {
            element =
                parentElement.getSetter(name.substring(0, name.length - 1));
          } else if (name.isEmpty) {
            element = parentElement.unnamedConstructor;
          } else {
            element = parentElement.getField(name) ??
                parentElement.getMethod(name) ??
                parentElement.getNamedConstructor(name);
          }
        } else {
          // The only elements that are currently retrieved using 4-component
          // locations are class members.
          throw new StateError(
              '4-element locations not supported for ${element.runtimeType}');
        }
      }
      if (element == null) {
        throw new Exception('Element not found in summary: $location');
      }
      return element;
    } else {
      throw new UnimplementedError(location.toString());
    }
  }

  /**
   * Get the [LibraryElement] for the given [uri], resynthesizing it if it
   * hasn't been resynthesized already.
   */
  LibraryElement getLibraryElement(String uri) {
    if (parent != null && parent._hasLibrarySummary(uri)) {
      return parent.getLibraryElement(uri);
    }
    return _resynthesizedLibraries.putIfAbsent(uri, () {
      LinkedLibrary serializedLibrary = _getLinkedSummaryOrThrow(uri);
      List<UnlinkedUnit> serializedUnits = <UnlinkedUnit>[
        _getUnlinkedSummaryOrThrow(uri)
      ];
      Source librarySource = _getSource(uri);
      for (String part in serializedUnits[0].publicNamespace.parts) {
        Source partSource = sourceFactory.resolveUri(librarySource, part);
        String partAbsUri = partSource.uri.toString();
        serializedUnits.add(_getUnlinkedSummaryOrThrow(partAbsUri));
      }
      _LibraryResynthesizer libraryResynthesizer = new _LibraryResynthesizer(
          this, serializedLibrary, serializedUnits, librarySource);
      LibraryElement library = libraryResynthesizer.buildLibrary();
      _resynthesizedElements[uri] = libraryResynthesizer.resummarizedElements;
      return library;
    });
  }

  /**
   * Return the [LinkedLibrary] for the given [uri] or `null` if it could not
   * be found.  Caller has already checked that `parent.hasLibrarySummary(uri)`
   * returns `false`.
   */
  LinkedLibrary getLinkedSummary(String uri);

  /**
   * Return the [UnlinkedUnit] for the given [uri] or `null` if it could not
   * be found.  Caller has already checked that `parent.hasLibrarySummary(uri)`
   * returns `false`.
   */
  UnlinkedUnit getUnlinkedSummary(String uri);

  /**
   * Return `true` if this resynthesizer can provide summaries of the libraries
   * with the given [uri].  Caller has already checked that
   * `parent.hasLibrarySummary(uri)` returns `false`.
   */
  bool hasLibrarySummary(String uri);

  /**
   * Return the [LinkedLibrary] for the given [uri] or throw [StateError] if it
   * could not be found.
   */
  LinkedLibrary _getLinkedSummaryOrThrow(String uri) {
    if (parent != null && parent._hasLibrarySummary(uri)) {
      return parent._getLinkedSummaryOrThrow(uri);
    }
    LinkedLibrary summary = getLinkedSummary(uri);
    if (summary != null) {
      return summary;
    }
    throw new StateError('Unable to find linked summary: $uri');
  }

  /**
   * Get the [Source] object for the given [uri].
   */
  Source _getSource(String uri) {
    return _sources.putIfAbsent(uri, () => sourceFactory.forUri(uri));
  }

  /**
   * Return the [UnlinkedUnit] for the given [uri] or throw [StateError] if it
   * could not be found.
   */
  UnlinkedUnit _getUnlinkedSummaryOrThrow(String uri) {
    if (parent != null && parent._hasLibrarySummary(uri)) {
      return parent._getUnlinkedSummaryOrThrow(uri);
    }
    UnlinkedUnit summary = getUnlinkedSummary(uri);
    if (summary != null) {
      return summary;
    }
    throw new StateError('Unable to find unlinked summary: $uri');
  }

  /**
   * Return `true` if this resynthesizer can provide summaries of the libraries
   * with the given [uri].
   */
  bool _hasLibrarySummary(String uri) {
    if (parent != null && parent._hasLibrarySummary(uri)) {
      return true;
    }
    return hasLibrarySummary(uri);
  }
}

/**
 * Builder of [Expression]s from [UnlinkedConst]s.
 */
class _ConstExprBuilder {
  final _LibraryResynthesizer resynthesizer;
  final UnlinkedConst uc;

  int intPtr = 0;
  int doublePtr = 0;
  int stringPtr = 0;
  int refPtr = 0;
  final List<Expression> stack = <Expression>[];

  _ConstExprBuilder(this.resynthesizer, this.uc);

  Expression get expr => stack.single;

  Expression build() {
    // TODO(scheglov) complete implementation
    for (UnlinkedConstOperation operation in uc.operations) {
      switch (operation) {
        case UnlinkedConstOperation.pushNull:
          _push(AstFactory.nullLiteral());
          break;
        // bool
        case UnlinkedConstOperation.pushFalse:
          _push(AstFactory.booleanLiteral(false));
          break;
        case UnlinkedConstOperation.pushTrue:
          _push(AstFactory.booleanLiteral(true));
          break;
        // literals
        case UnlinkedConstOperation.pushInt:
          int value = uc.ints[intPtr++];
          _push(AstFactory.integer(value));
          break;
        case UnlinkedConstOperation.pushLongInt:
          int value = 0;
          int count = uc.ints[intPtr++];
          for (int i = 0; i < count; i++) {
            int next = uc.ints[intPtr++];
            value = value << 32 | next;
          }
          _push(AstFactory.integer(value));
          break;
        case UnlinkedConstOperation.pushDouble:
          double value = uc.doubles[doublePtr++];
          _push(AstFactory.doubleLiteral(value));
          break;
        case UnlinkedConstOperation.makeSymbol:
          String component = uc.strings[stringPtr++];
          _push(AstFactory.symbolLiteral([component]));
          break;
        // String
        case UnlinkedConstOperation.pushString:
          String value = uc.strings[stringPtr++];
          _push(AstFactory.string2(value));
          break;
        case UnlinkedConstOperation.concatenate:
          int count = uc.ints[intPtr++];
          List<InterpolationElement> elements = <InterpolationElement>[];
          for (int i = 0; i < count; i++) {
            Expression expr = _pop();
            InterpolationElement element = _newInterpolationElement(expr);
            elements.insert(0, element);
          }
          _push(AstFactory.string(elements));
          break;
        // binary
        case UnlinkedConstOperation.equal:
          _pushBinary(TokenType.EQ_EQ);
          break;
        case UnlinkedConstOperation.notEqual:
          _pushBinary(TokenType.BANG_EQ);
          break;
        case UnlinkedConstOperation.and:
          _pushBinary(TokenType.AMPERSAND_AMPERSAND);
          break;
        case UnlinkedConstOperation.or:
          _pushBinary(TokenType.BAR_BAR);
          break;
        case UnlinkedConstOperation.bitXor:
          _pushBinary(TokenType.CARET);
          break;
        case UnlinkedConstOperation.bitAnd:
          _pushBinary(TokenType.AMPERSAND);
          break;
        case UnlinkedConstOperation.bitOr:
          _pushBinary(TokenType.BAR);
          break;
        case UnlinkedConstOperation.bitShiftLeft:
          _pushBinary(TokenType.LT_LT);
          break;
        case UnlinkedConstOperation.bitShiftRight:
          _pushBinary(TokenType.GT_GT);
          break;
        case UnlinkedConstOperation.add:
          _pushBinary(TokenType.PLUS);
          break;
        case UnlinkedConstOperation.subtract:
          _pushBinary(TokenType.MINUS);
          break;
        case UnlinkedConstOperation.multiply:
          _pushBinary(TokenType.STAR);
          break;
        case UnlinkedConstOperation.divide:
          _pushBinary(TokenType.SLASH);
          break;
        case UnlinkedConstOperation.floorDivide:
          _pushBinary(TokenType.TILDE_SLASH);
          break;
        case UnlinkedConstOperation.modulo:
          _pushBinary(TokenType.PERCENT);
          break;
        case UnlinkedConstOperation.greater:
          _pushBinary(TokenType.GT);
          break;
        case UnlinkedConstOperation.greaterEqual:
          _pushBinary(TokenType.GT_EQ);
          break;
        case UnlinkedConstOperation.less:
          _pushBinary(TokenType.LT);
          break;
        case UnlinkedConstOperation.lessEqual:
          _pushBinary(TokenType.LT_EQ);
          break;
        // prefix
        case UnlinkedConstOperation.complement:
          _pushPrefix(TokenType.TILDE);
          break;
        case UnlinkedConstOperation.negate:
          _pushPrefix(TokenType.MINUS);
          break;
        case UnlinkedConstOperation.not:
          _pushPrefix(TokenType.BANG);
          break;
        // conditional
        case UnlinkedConstOperation.conditional:
          Expression elseExpr = _pop();
          Expression thenExpr = _pop();
          Expression condition = _pop();
          _push(
              AstFactory.conditionalExpression(condition, thenExpr, elseExpr));
          break;
        // identical
        case UnlinkedConstOperation.identical:
          Expression second = _pop();
          Expression first = _pop();
          _push(AstFactory.methodInvocation(
              null, 'identical', <Expression>[first, second]));
          break;
        // containers
        case UnlinkedConstOperation.makeUntypedList:
          _pushList(null);
          break;
        case UnlinkedConstOperation.makeTypedList:
          TypeName itemType = _newTypeName();
          _pushList(AstFactory.typeArgumentList(<TypeName>[itemType]));
          break;
        case UnlinkedConstOperation.makeUntypedMap:
          _pushMap(null);
          break;
        case UnlinkedConstOperation.makeTypedMap:
          TypeName keyType = _newTypeName();
          TypeName valueType = _newTypeName();
          _pushMap(AstFactory.typeArgumentList(<TypeName>[keyType, valueType]));
          break;
        case UnlinkedConstOperation.pushReference:
        case UnlinkedConstOperation.invokeConstructor:
        case UnlinkedConstOperation.length:
          return AstFactory.nullLiteral();
//          throw new StateError('Unsupported constant operation $operation');
      }
    }
    return stack.single;
  }

  TypeName _buildTypeAst(DartType type) {
    if (type is DynamicTypeImpl) {
      TypeName node = AstFactory.typeName4('dynamic');
      node.type = type;
      (node.name as SimpleIdentifier).staticElement = type.element;
      return node;
    } else if (type is InterfaceType) {
      List<TypeName> argumentNodes =
          type.typeArguments.map(_buildTypeAst).toList();
      TypeName node = AstFactory.typeName4(type.name, argumentNodes);
      node.type = type;
      (node.name as SimpleIdentifier).staticElement = type.element;
      return node;
    }
    throw new StateError('Unsupported type $type');
  }

  InterpolationElement _newInterpolationElement(Expression expr) {
    if (expr is SimpleStringLiteral) {
      return new InterpolationString(expr.literal, expr.value);
    } else {
      return new InterpolationExpression(
          TokenFactory.tokenFromType(TokenType.STRING_INTERPOLATION_EXPRESSION),
          expr,
          TokenFactory.tokenFromType(TokenType.CLOSE_CURLY_BRACKET));
    }
  }

  /**
   * Convert the next reference to the [DartType] and return the AST
   * corresponding to this type.
   */
  TypeName _newTypeName() {
    EntityRef typeRef = uc.references[refPtr++];
    DartType type = resynthesizer.buildType(typeRef);
    return _buildTypeAst(type);
  }

  Expression _pop() => stack.removeLast();

  void _push(Expression expr) {
    stack.add(expr);
  }

  void _pushBinary(TokenType operator) {
    Expression right = _pop();
    Expression left = _pop();
    _push(AstFactory.binaryExpression(left, operator, right));
  }

  void _pushList(TypeArgumentList typeArguments) {
    int count = uc.ints[intPtr++];
    List<Expression> elements = <Expression>[];
    for (int i = 0; i < count; i++) {
      elements.insert(0, _pop());
    }
    _push(AstFactory.listLiteral2(Keyword.CONST, typeArguments, elements));
  }

  void _pushMap(TypeArgumentList typeArguments) {
    int count = uc.ints[intPtr++];
    List<MapLiteralEntry> entries = <MapLiteralEntry>[];
    for (int i = 0; i < count; i++) {
      Expression value = _pop();
      Expression key = _pop();
      entries.insert(0, AstFactory.mapLiteralEntry2(key, value));
    }
    _push(AstFactory.mapLiteral(Keyword.CONST, typeArguments, entries));
  }

  void _pushPrefix(TokenType operator) {
    Expression operand = _pop();
    _push(AstFactory.prefixExpression(operator, operand));
  }
}

/**
 * An instance of [_LibraryResynthesizer] is responsible for resynthesizing the
 * elements in a single library from that library's summary.
 */
class _LibraryResynthesizer {
  /**
   * The [SummaryResynthesizer] which is being used to obtain summaries.
   */
  final SummaryResynthesizer summaryResynthesizer;

  /**
   * Linked summary of the library to be resynthesized.
   */
  final LinkedLibrary linkedLibrary;

  /**
   * Unlinked compilation units constituting the library to be resynthesized.
   */
  final List<UnlinkedUnit> unlinkedUnits;

  /**
   * [Source] object for the library to be resynthesized.
   */
  final Source librarySource;

  /**
   * Indicates whether [librarySource] is the `dart:core` library.
   */
  bool isCoreLibrary;

  /**
   * Classes which should have their supertype set to "object" once
   * resynthesis is complete.  Only used if [isCoreLibrary] is `true`.
   */
  List<ClassElementImpl> delayedObjectSubclasses = <ClassElementImpl>[];

  /**
   * [ElementHolder] into which resynthesized elements should be placed.  This
   * object is recreated afresh for each unit in the library, and is used to
   * populate the [CompilationUnitElement].
   */
  ElementHolder unitHolder;

  /**
   * The [LinkedUnit] from which elements are currently being resynthesized.
   */
  LinkedUnit linkedUnit;

  /**
   * The [UnlinkedUnit] from which elements are currently being resynthesized.
   */
  UnlinkedUnit unlinkedUnit;

  /**
   * Map from slot id to the corresponding [EntityRef] object for linked types
   * (i.e. propagated and inferred types).
   */
  Map<int, EntityRef> linkedTypeMap;

  /**
   * Map of top level elements that have been resynthesized so far.  The first
   * key is the URI of the compilation unit; the second is the name of the top
   * level element.
   */
  final Map<String, Map<String, Element>> resummarizedElements =
      <String, Map<String, Element>>{};

  /**
   * Type parameters for the generic class, typedef, or executable currently
   * being resynthesized, if any.  If multiple entities with type parameters
   * are nested (e.g. a generic executable inside a generic class), this is the
   * concatenation of all type parameters from all declarations currently in
   * force, with the outermost declaration appearing first.  If there are no
   * type parameters, or we are not currently resynthesizing a class, typedef,
   * or executable, then this is an empty list.
   */
  List<TypeParameterElement> currentTypeParameters = <TypeParameterElement>[];

  /**
   * If a class is currently being resynthesized, map from field name to the
   * corresponding field element.  This is used when resynthesizing
   * initializing formal parameters.
   */
  Map<String, FieldElementImpl> fields;

  /**
   * List of [_ReferenceInfo] objects describing the references in the current
   * compilation unit.
   */
  List<_ReferenceInfo> referenceInfos;

  _LibraryResynthesizer(this.summaryResynthesizer, this.linkedLibrary,
      this.unlinkedUnits, this.librarySource) {
    isCoreLibrary = librarySource.uri.toString() == 'dart:core';
  }

  /**
   * Return a list of type arguments corresponding to [currentTypeParameters].
   */
  List<TypeParameterType> get currentTypeArguments => currentTypeParameters
      ?.map((TypeParameterElement param) => param.type)
      ?.toList();

  /**
   * Resynthesize a [ClassElement] and place it in [unitHolder].
   */
  void buildClass(UnlinkedClass serializedClass) {
    try {
      currentTypeParameters =
          serializedClass.typeParameters.map(buildTypeParameter).toList();
      for (int i = 0; i < serializedClass.typeParameters.length; i++) {
        finishTypeParameter(
            serializedClass.typeParameters[i], currentTypeParameters[i]);
      }
      ClassElementImpl classElement = new ClassElementImpl(
          serializedClass.name, serializedClass.nameOffset);
      classElement.abstract = serializedClass.isAbstract;
      classElement.mixinApplication = serializedClass.isMixinApplication;
      InterfaceTypeImpl correspondingType = new InterfaceTypeImpl(classElement);
      if (serializedClass.supertype != null) {
        classElement.supertype = buildType(serializedClass.supertype);
      } else if (!serializedClass.hasNoSupertype) {
        if (isCoreLibrary) {
          delayedObjectSubclasses.add(classElement);
        } else {
          classElement.supertype = summaryResynthesizer.typeProvider.objectType;
        }
      }
      classElement.interfaces =
          serializedClass.interfaces.map(buildType).toList();
      classElement.mixins = serializedClass.mixins.map(buildType).toList();
      classElement.typeParameters = currentTypeParameters;
      ElementHolder memberHolder = new ElementHolder();
      fields = <String, FieldElementImpl>{};
      for (UnlinkedVariable serializedVariable in serializedClass.fields) {
        buildVariable(serializedVariable, memberHolder);
      }
      bool constructorFound = false;
      for (UnlinkedExecutable serializedExecutable
          in serializedClass.executables) {
        switch (serializedExecutable.kind) {
          case UnlinkedExecutableKind.constructor:
            constructorFound = true;
            buildConstructor(
                serializedExecutable, memberHolder, correspondingType);
            break;
          case UnlinkedExecutableKind.functionOrMethod:
          case UnlinkedExecutableKind.getter:
          case UnlinkedExecutableKind.setter:
            buildExecutable(serializedExecutable, memberHolder);
            break;
        }
      }
      if (!serializedClass.isMixinApplication) {
        if (!constructorFound) {
          // Synthesize implicit constructors.
          ConstructorElementImpl constructor =
              new ConstructorElementImpl('', -1);
          constructor.synthetic = true;
          constructor.returnType = correspondingType;
          constructor.type = new FunctionTypeImpl.elementWithNameAndArgs(
              constructor, null, currentTypeArguments, false);
          memberHolder.addConstructor(constructor);
        }
        classElement.constructors = memberHolder.constructors;
      }
      classElement.accessors = memberHolder.accessors;
      classElement.fields = memberHolder.fields;
      classElement.methods = memberHolder.methods;
      correspondingType.typeArguments = currentTypeArguments;
      classElement.type = correspondingType;
      buildDocumentation(classElement, serializedClass.documentationComment);
      unitHolder.addType(classElement);
    } finally {
      currentTypeParameters = <TypeParameterElement>[];
      fields = null;
    }
  }

  /**
   * Resynthesize a [NamespaceCombinator].
   */
  NamespaceCombinator buildCombinator(UnlinkedCombinator serializedCombinator) {
    if (serializedCombinator.shows.isNotEmpty) {
      ShowElementCombinatorImpl combinator = new ShowElementCombinatorImpl();
      // Note: we call toList() so that we don't retain a reference to the
      // deserialized data structure.
      combinator.shownNames = serializedCombinator.shows.toList();
      return combinator;
    } else {
      HideElementCombinatorImpl combinator = new HideElementCombinatorImpl();
      // Note: we call toList() so that we don't retain a reference to the
      // deserialized data structure.
      combinator.hiddenNames = serializedCombinator.hides.toList();
      return combinator;
    }
  }

  /**
   * Resynthesize a [ConstructorElement] and place it in the given [holder].
   * [classType] is the type of the class for which this element is a
   * constructor.
   */
  void buildConstructor(UnlinkedExecutable serializedExecutable,
      ElementHolder holder, InterfaceType classType) {
    assert(serializedExecutable.kind == UnlinkedExecutableKind.constructor);
    ConstructorElementImpl constructorElement = new ConstructorElementImpl(
        serializedExecutable.name, serializedExecutable.nameOffset);
    constructorElement.returnType = classType;
    buildExecutableCommonParts(constructorElement, serializedExecutable);
    constructorElement.factory = serializedExecutable.isFactory;
    constructorElement.const2 = serializedExecutable.isConst;
    holder.addConstructor(constructorElement);
  }

  /**
   * Build the documentation for the given [element].  Does nothing if
   * [serializedDocumentationComment] is `null`.
   */
  void buildDocumentation(ElementImpl element,
      UnlinkedDocumentationComment serializedDocumentationComment) {
    if (serializedDocumentationComment != null) {
      element.documentationComment = serializedDocumentationComment.text;
      element.setDocRange(serializedDocumentationComment.offset,
          serializedDocumentationComment.length);
    }
  }

  /**
   * Resynthesize the [ClassElement] corresponding to an enum, along with the
   * associated fields and implicit accessors.
   */
  void buildEnum(UnlinkedEnum serializedEnum) {
    assert(!isCoreLibrary);
    ClassElementImpl classElement =
        new ClassElementImpl(serializedEnum.name, serializedEnum.nameOffset);
    classElement.enum2 = true;
    InterfaceType enumType = new InterfaceTypeImpl(classElement);
    classElement.type = enumType;
    classElement.supertype = summaryResynthesizer.typeProvider.objectType;
    buildDocumentation(classElement, serializedEnum.documentationComment);
    ElementHolder memberHolder = new ElementHolder();
    FieldElementImpl indexField = new FieldElementImpl('index', -1);
    indexField.final2 = true;
    indexField.synthetic = true;
    indexField.type = summaryResynthesizer.typeProvider.intType;
    memberHolder.addField(indexField);
    buildImplicitAccessors(indexField, memberHolder);
    FieldElementImpl valuesField = new ConstFieldElementImpl('values', -1);
    valuesField.synthetic = true;
    valuesField.const3 = true;
    valuesField.static = true;
    valuesField.type = summaryResynthesizer.typeProvider.listType
        .substitute4(<DartType>[enumType]);
    memberHolder.addField(valuesField);
    buildImplicitAccessors(valuesField, memberHolder);
    for (UnlinkedEnumValue serializedEnumValue in serializedEnum.values) {
      ConstFieldElementImpl valueField = new ConstFieldElementImpl(
          serializedEnumValue.name, serializedEnumValue.nameOffset);
      valueField.const3 = true;
      valueField.static = true;
      valueField.type = enumType;
      memberHolder.addField(valueField);
      buildImplicitAccessors(valueField, memberHolder);
    }
    classElement.fields = memberHolder.fields;
    classElement.accessors = memberHolder.accessors;
    classElement.constructors = <ConstructorElement>[];
    unitHolder.addEnum(classElement);
  }

  /**
   * Resynthesize an [ExecutableElement] and place it in the given [holder].
   */
  void buildExecutable(UnlinkedExecutable serializedExecutable,
      [ElementHolder holder]) {
    bool isTopLevel = holder == null;
    if (holder == null) {
      holder = unitHolder;
    }
    UnlinkedExecutableKind kind = serializedExecutable.kind;
    String name = serializedExecutable.name;
    if (kind == UnlinkedExecutableKind.setter) {
      assert(name.endsWith('='));
      name = name.substring(0, name.length - 1);
    }
    switch (kind) {
      case UnlinkedExecutableKind.functionOrMethod:
        if (isTopLevel) {
          FunctionElementImpl executableElement =
              new FunctionElementImpl(name, serializedExecutable.nameOffset);
          buildExecutableCommonParts(executableElement, serializedExecutable);
          holder.addFunction(executableElement);
        } else {
          MethodElementImpl executableElement =
              new MethodElementImpl(name, serializedExecutable.nameOffset);
          executableElement.abstract = serializedExecutable.isAbstract;
          buildExecutableCommonParts(executableElement, serializedExecutable);
          executableElement.static = serializedExecutable.isStatic;
          holder.addMethod(executableElement);
        }
        break;
      case UnlinkedExecutableKind.getter:
      case UnlinkedExecutableKind.setter:
        PropertyAccessorElementImpl executableElement =
            new PropertyAccessorElementImpl(
                name, serializedExecutable.nameOffset);
        if (isTopLevel) {
          executableElement.static = true;
        } else {
          executableElement.static = serializedExecutable.isStatic;
          executableElement.abstract = serializedExecutable.isAbstract;
        }
        buildExecutableCommonParts(executableElement, serializedExecutable);
        DartType type;
        if (kind == UnlinkedExecutableKind.getter) {
          executableElement.getter = true;
          type = executableElement.returnType;
        } else {
          executableElement.setter = true;
          type = executableElement.parameters[0].type;
        }
        holder.addAccessor(executableElement);
        // TODO(paulberry): consider removing implicit variables from the
        // element model; the spec doesn't call for them, and they cause
        // trouble when getters/setters exist in different parts.
        PropertyInducingElementImpl implicitVariable;
        if (isTopLevel) {
          implicitVariable = buildImplicitTopLevelVariable(name, kind, holder);
        } else {
          FieldElementImpl field = buildImplicitField(name, type, kind, holder);
          field.static = serializedExecutable.isStatic;
          implicitVariable = field;
        }
        executableElement.variable = implicitVariable;
        if (kind == UnlinkedExecutableKind.getter) {
          implicitVariable.getter = executableElement;
        } else {
          implicitVariable.setter = executableElement;
        }
        break;
      default:
        // The only other executable type is a constructor, and that is handled
        // separately (in [buildConstructor].  So this code should be
        // unreachable.
        assert(false);
    }
  }

  /**
   * Handle the parts of an executable element that are common to constructors,
   * functions, methods, getters, and setters.
   */
  void buildExecutableCommonParts(ExecutableElementImpl executableElement,
      UnlinkedExecutable serializedExecutable) {
    List<TypeParameterType> oldTypeArguments = currentTypeArguments;
    int oldTypeParametersLength = currentTypeParameters.length;
    if (serializedExecutable.typeParameters.isNotEmpty) {
      executableElement.typeParameters =
          serializedExecutable.typeParameters.map(buildTypeParameter).toList();
      currentTypeParameters.addAll(executableElement.typeParameters);
    }
    executableElement.parameters =
        serializedExecutable.parameters.map(buildParameter).toList();
    if (serializedExecutable.kind == UnlinkedExecutableKind.constructor) {
      // Caller handles setting the return type.
      assert(serializedExecutable.returnType == null);
    } else {
      bool isSetter =
          serializedExecutable.kind == UnlinkedExecutableKind.setter;
      executableElement.returnType =
          buildLinkedType(serializedExecutable.inferredReturnTypeSlot) ??
              buildType(serializedExecutable.returnType,
                  defaultVoid: isSetter && summaryResynthesizer.strongMode);
      executableElement.hasImplicitReturnType =
          serializedExecutable.returnType == null;
    }
    executableElement.type = new FunctionTypeImpl.elementWithNameAndArgs(
        executableElement, null, oldTypeArguments, false);
    executableElement.external = serializedExecutable.isExternal;
    currentTypeParameters.removeRange(
        oldTypeParametersLength, currentTypeParameters.length);
    buildDocumentation(
        executableElement, serializedExecutable.documentationComment);
  }

  /**
   * Resynthesize an [ExportElement],
   */
  ExportElement buildExport(UnlinkedExportPublic serializedExportPublic,
      UnlinkedExportNonPublic serializedExportNonPublic) {
    ExportElementImpl exportElement =
        new ExportElementImpl(serializedExportNonPublic.offset);
    String exportedLibraryUri = summaryResynthesizer.sourceFactory
        .resolveUri(librarySource, serializedExportPublic.uri)
        .uri
        .toString();
    exportElement.exportedLibrary = new LibraryElementHandle(
        summaryResynthesizer,
        new ElementLocationImpl.con3(<String>[exportedLibraryUri]));
    exportElement.uri = serializedExportPublic.uri;
    exportElement.combinators =
        serializedExportPublic.combinators.map(buildCombinator).toList();
    exportElement.uriOffset = serializedExportNonPublic.uriOffset;
    exportElement.uriEnd = serializedExportNonPublic.uriEnd;
    return exportElement;
  }

  /**
   * Build an [ElementHandle] referring to the entity referred to by the given
   * [exportName].
   */
  ElementHandle buildExportName(LinkedExportName exportName) {
    String name = exportName.name;
    if (exportName.kind == ReferenceKind.topLevelPropertyAccessor &&
        !name.endsWith('=')) {
      name += '?';
    }
    ElementLocationImpl location = new ElementLocationImpl.con3(
        getReferencedLocationComponents(
            exportName.dependency, exportName.unit, name));
    switch (exportName.kind) {
      case ReferenceKind.classOrEnum:
        return new ClassElementHandle(summaryResynthesizer, location);
      case ReferenceKind.typedef:
        return new FunctionTypeAliasElementHandle(
            summaryResynthesizer, location);
      case ReferenceKind.topLevelFunction:
        return new FunctionElementHandle(summaryResynthesizer, location);
      case ReferenceKind.topLevelPropertyAccessor:
        return new PropertyAccessorElementHandle(
            summaryResynthesizer, location);
      case ReferenceKind.constructor:
      case ReferenceKind.propertyAccessor:
      case ReferenceKind.method:
      case ReferenceKind.length:
      case ReferenceKind.prefix:
      case ReferenceKind.unresolved:
        // Should never happen.  Exported names never refer to import prefixes,
        // and they always refer to defined top-level entities.
        throw new StateError('Unexpected export name kind: ${exportName.kind}');
    }
  }

  /**
   * Build the export namespace for the library by aggregating together its
   * [publicNamespace] and [exportNames].
   */
  Namespace buildExportNamespace(
      Namespace publicNamespace, List<LinkedExportName> exportNames) {
    HashMap<String, Element> definedNames = new HashMap<String, Element>();
    // Start by populating all the public names from [publicNamespace].
    publicNamespace.definedNames.forEach((String name, Element element) {
      definedNames[name] = element;
    });
    // Add all the names from [exportNames].
    for (LinkedExportName exportName in exportNames) {
      definedNames.putIfAbsent(
          exportName.name, () => buildExportName(exportName));
    }
    return new Namespace(definedNames);
  }

  /**
   * Resynthesize a [FieldElement].
   */
  FieldElement buildField(UnlinkedVariable serializedField) {
    FieldElementImpl fieldElement =
        new FieldElementImpl(serializedField.name, -1);
    fieldElement.type = buildType(serializedField.type);
    fieldElement.const3 = serializedField.isConst;
    return fieldElement;
  }

  /**
   * Build the implicit getter and setter associated with [element], and place
   * them in [holder].
   */
  void buildImplicitAccessors(
      PropertyInducingElementImpl element, ElementHolder holder) {
    String name = element.name;
    DartType type = element.type;
    PropertyAccessorElementImpl getter =
        new PropertyAccessorElementImpl(name, element.nameOffset);
    getter.getter = true;
    getter.static = element.isStatic;
    getter.synthetic = true;
    getter.returnType = type;
    getter.type = new FunctionTypeImpl(getter);
    getter.variable = element;
    getter.hasImplicitReturnType = element.hasImplicitType;
    holder.addAccessor(getter);
    element.getter = getter;
    if (!(element.isConst || element.isFinal)) {
      PropertyAccessorElementImpl setter =
          new PropertyAccessorElementImpl(name, element.nameOffset);
      setter.setter = true;
      setter.static = element.isStatic;
      setter.synthetic = true;
      setter.parameters = <ParameterElement>[
        new ParameterElementImpl('_$name', element.nameOffset)
          ..synthetic = true
          ..type = type
          ..parameterKind = ParameterKind.REQUIRED
      ];
      setter.returnType = VoidTypeImpl.instance;
      setter.type = new FunctionTypeImpl(setter);
      setter.variable = element;
      holder.addAccessor(setter);
      element.setter = setter;
    }
  }

  /**
   * Build the implicit field associated with a getter or setter, and place it
   * in [holder].
   */
  FieldElementImpl buildImplicitField(String name, DartType type,
      UnlinkedExecutableKind kind, ElementHolder holder) {
    FieldElementImpl field = holder.getField(name);
    if (field == null) {
      field = new FieldElementImpl(name, -1);
      field.synthetic = true;
      field.final2 = kind == UnlinkedExecutableKind.getter;
      field.type = type;
      holder.addField(field);
      return field;
    } else {
      // TODO(paulberry): what if the getter and setter have a type mismatch?
      field.final2 = false;
      return field;
    }
  }

  /**
   * Build the implicit top level variable associated with a getter or setter,
   * and place it in [holder].
   */
  PropertyInducingElementImpl buildImplicitTopLevelVariable(
      String name, UnlinkedExecutableKind kind, ElementHolder holder) {
    TopLevelVariableElementImpl variable = holder.getTopLevelVariable(name);
    if (variable == null) {
      variable = new TopLevelVariableElementImpl(name, -1);
      variable.synthetic = true;
      variable.final2 = kind == UnlinkedExecutableKind.getter;
      holder.addTopLevelVariable(variable);
      return variable;
    } else {
      // TODO(paulberry): what if the getter and setter have a type mismatch?
      variable.final2 = false;
      return variable;
    }
  }

  /**
   * Resynthesize an [ImportElement].
   */
  ImportElement buildImport(UnlinkedImport serializedImport, int dependency) {
    bool isSynthetic = serializedImport.isImplicit;
    ImportElementImpl importElement =
        new ImportElementImpl(isSynthetic ? -1 : serializedImport.offset);
    String absoluteUri = summaryResynthesizer.sourceFactory
        .resolveUri(librarySource, linkedLibrary.dependencies[dependency].uri)
        .uri
        .toString();
    importElement.importedLibrary = new LibraryElementHandle(
        summaryResynthesizer,
        new ElementLocationImpl.con3(<String>[absoluteUri]));
    if (isSynthetic) {
      importElement.synthetic = true;
    } else {
      importElement.uri = serializedImport.uri;
      importElement.uriOffset = serializedImport.uriOffset;
      importElement.uriEnd = serializedImport.uriEnd;
      importElement.deferred = serializedImport.isDeferred;
    }
    importElement.prefixOffset = serializedImport.prefixOffset;
    if (serializedImport.prefixReference != 0) {
      UnlinkedReference serializedPrefix =
          unlinkedUnits[0].references[serializedImport.prefixReference];
      importElement.prefix = new PrefixElementImpl(
          serializedPrefix.name, serializedImport.prefixOffset);
    }
    importElement.combinators =
        serializedImport.combinators.map(buildCombinator).toList();
    return importElement;
  }

  /**
   * Main entry point.  Resynthesize the [LibraryElement] and return it.
   */
  LibraryElement buildLibrary() {
    bool hasName = unlinkedUnits[0].libraryName.isNotEmpty;
    LibraryElementImpl library = new LibraryElementImpl(
        summaryResynthesizer.context,
        unlinkedUnits[0].libraryName,
        hasName ? unlinkedUnits[0].libraryNameOffset : -1,
        unlinkedUnits[0].libraryNameLength);
    buildDocumentation(library, unlinkedUnits[0].libraryDocumentationComment);
    CompilationUnitElementImpl definingCompilationUnit =
        new CompilationUnitElementImpl(librarySource.shortName);
    library.definingCompilationUnit = definingCompilationUnit;
    definingCompilationUnit.source = librarySource;
    definingCompilationUnit.librarySource = librarySource;
    List<CompilationUnitElement> parts = <CompilationUnitElement>[];
    UnlinkedUnit unlinkedDefiningUnit = unlinkedUnits[0];
    assert(unlinkedDefiningUnit.publicNamespace.parts.length + 1 ==
        linkedLibrary.units.length);
    for (int i = 1; i < linkedLibrary.units.length; i++) {
      CompilationUnitElementImpl part = buildPart(
          unlinkedDefiningUnit.publicNamespace.parts[i - 1],
          unlinkedDefiningUnit.parts[i - 1],
          unlinkedUnits[i]);
      parts.add(part);
    }
    library.parts = parts;
    List<ImportElement> imports = <ImportElement>[];
    for (int i = 0; i < unlinkedDefiningUnit.imports.length; i++) {
      imports.add(buildImport(unlinkedDefiningUnit.imports[i],
          linkedLibrary.importDependencies[i]));
    }
    library.imports = imports;
    List<ExportElement> exports = <ExportElement>[];
    assert(unlinkedDefiningUnit.exports.length ==
        unlinkedDefiningUnit.publicNamespace.exports.length);
    for (int i = 0; i < unlinkedDefiningUnit.exports.length; i++) {
      exports.add(buildExport(unlinkedDefiningUnit.publicNamespace.exports[i],
          unlinkedDefiningUnit.exports[i]));
    }
    library.exports = exports;
    populateUnit(definingCompilationUnit, 0);
    for (int i = 0; i < parts.length; i++) {
      populateUnit(parts[i], i + 1);
    }
    BuildLibraryElementUtils.patchTopLevelAccessors(library);
    // Update delayed Object class references.
    if (isCoreLibrary) {
      ClassElement objectElement = library.getType('Object');
      assert(objectElement != null);
      for (ClassElementImpl classElement in delayedObjectSubclasses) {
        classElement.supertype = objectElement.type;
      }
    }
    // Compute namespaces.
    library.publicNamespace =
        new NamespaceBuilder().createPublicNamespaceForLibrary(library);
    library.exportNamespace = buildExportNamespace(
        library.publicNamespace, linkedLibrary.exportNames);
    // Find the entry point.  Note: we can't use element.isEntryPoint because
    // that will trigger resynthesis of exported libraries.
    Element entryPoint =
        library.exportNamespace.get(FunctionElement.MAIN_FUNCTION_NAME);
    if (entryPoint is FunctionElement) {
      library.entryPoint = entryPoint;
    }
    // Create the synthetic element for `loadLibrary`.
    // Until the client received dart:core and dart:async, we cannot do this,
    // because the TypeProvider is not fully initialized. So, it is up to the
    // Dart SDK client to initialize TypeProvider and finish the dart:core and
    // dart:async libraries creation.
    if (library.name != 'dart.core' && library.name != 'dart.async') {
      library.createLoadLibraryFunction(summaryResynthesizer.typeProvider);
    }
    // Done.
    return library;
  }

  /**
   * Build the appropriate [DartType] object corresponding to a slot id in the
   * [LinkedUnit.types] table.
   */
  DartType buildLinkedType(int slot) {
    if (slot == 0) {
      // A slot id of 0 means there is no [DartType] object to build.
      return null;
    }
    EntityRef type = linkedTypeMap[slot];
    if (type == null) {
      // A missing entry in [LinkedUnit.types] means there is no [DartType]
      // stored in this slot.
      return null;
    }
    return buildType(type);
  }

  /**
   * Resynthesize a [ParameterElement].
   */
  ParameterElement buildParameter(UnlinkedParam serializedParameter) {
    ParameterElementImpl parameterElement;
    if (serializedParameter.isInitializingFormal) {
      parameterElement = new FieldFormalParameterElementImpl.forNameAndOffset(
          serializedParameter.name, serializedParameter.nameOffset)
        ..field = fields[serializedParameter.name];
    } else {
      parameterElement = new ParameterElementImpl(
          serializedParameter.name, serializedParameter.nameOffset);
    }
    if (serializedParameter.isFunctionTyped) {
      FunctionElementImpl parameterTypeElement =
          new FunctionElementImpl('', -1);
      parameterTypeElement.synthetic = true;
      parameterElement.parameters =
          serializedParameter.parameters.map(buildParameter).toList();
      parameterTypeElement.enclosingElement = parameterElement;
      parameterTypeElement.shareParameters(parameterElement.parameters);
      parameterTypeElement.returnType = buildType(serializedParameter.type);
      parameterElement.type = new FunctionTypeImpl.elementWithNameAndArgs(
          parameterTypeElement, null, currentTypeArguments, false);
    } else {
      if (serializedParameter.isInitializingFormal &&
          serializedParameter.type == null) {
        // The type is inherited from the matching field.
        parameterElement.type = fields[serializedParameter.name]?.type ??
            summaryResynthesizer.typeProvider.dynamicType;
      } else {
        parameterElement.type =
            buildLinkedType(serializedParameter.inferredTypeSlot) ??
                buildType(serializedParameter.type);
      }
      parameterElement.hasImplicitType = serializedParameter.type == null;
    }
    switch (serializedParameter.kind) {
      case UnlinkedParamKind.named:
        parameterElement.parameterKind = ParameterKind.NAMED;
        break;
      case UnlinkedParamKind.positional:
        parameterElement.parameterKind = ParameterKind.POSITIONAL;
        break;
      case UnlinkedParamKind.required:
        parameterElement.parameterKind = ParameterKind.REQUIRED;
        break;
    }
    return parameterElement;
  }

  /**
   * Create, but do not populate, the [CompilationUnitElement] for a part other
   * than the defining compilation unit.
   */
  CompilationUnitElementImpl buildPart(
      String uri, UnlinkedPart partDecl, UnlinkedUnit serializedPart) {
    Source unitSource =
        summaryResynthesizer.sourceFactory.resolveUri(librarySource, uri);
    CompilationUnitElementImpl partUnit =
        new CompilationUnitElementImpl(unitSource.shortName);
    partUnit.uriOffset = partDecl.uriOffset;
    partUnit.uriEnd = partDecl.uriEnd;
    partUnit.source = unitSource;
    partUnit.librarySource = librarySource;
    partUnit.uri = uri;
    return partUnit;
  }

  /**
   * Build a [DartType] object based on a [EntityRef].  This [DartType]
   * may refer to elements in other libraries than the library being
   * deserialized, so handles are used to avoid having to deserialize other
   * libraries in the process.
   */
  DartType buildType(EntityRef type, {bool defaultVoid: false}) {
    if (type == null) {
      if (defaultVoid) {
        return VoidTypeImpl.instance;
      } else {
        return summaryResynthesizer.typeProvider.dynamicType;
      }
    }
    if (type.paramReference != 0) {
      // TODO(paulberry): make this work for generic methods.
      return currentTypeParameters[
              currentTypeParameters.length - type.paramReference]
          .type;
    } else {
      DartType getTypeParameter(int i) {
        if (i < type.typeArguments.length) {
          return buildType(type.typeArguments[i]);
        } else {
          return summaryResynthesizer.typeProvider.dynamicType;
        }
      }
      _ReferenceInfo referenceInfo = referenceInfos[type.reference];
      return referenceInfo.buildType(
          getTypeParameter, type.implicitFunctionTypeIndices);
    }
  }

  /**
   * Resynthesize a [FunctionTypeAliasElement] and place it in the
   * [unitHolder].
   */
  void buildTypedef(UnlinkedTypedef serializedTypedef) {
    try {
      currentTypeParameters =
          serializedTypedef.typeParameters.map(buildTypeParameter).toList();
      for (int i = 0; i < serializedTypedef.typeParameters.length; i++) {
        finishTypeParameter(
            serializedTypedef.typeParameters[i], currentTypeParameters[i]);
      }
      FunctionTypeAliasElementImpl functionTypeAliasElement =
          new FunctionTypeAliasElementImpl(
              serializedTypedef.name, serializedTypedef.nameOffset);
      functionTypeAliasElement.parameters =
          serializedTypedef.parameters.map(buildParameter).toList();
      functionTypeAliasElement.returnType =
          buildType(serializedTypedef.returnType);
      functionTypeAliasElement.type =
          new FunctionTypeImpl.forTypedef(functionTypeAliasElement);
      functionTypeAliasElement.typeParameters = currentTypeParameters;
      buildDocumentation(
          functionTypeAliasElement, serializedTypedef.documentationComment);
      unitHolder.addTypeAlias(functionTypeAliasElement);
    } finally {
      currentTypeParameters = <TypeParameterElement>[];
    }
  }

  /**
   * Resynthesize a [TypeParameterElement], handling all parts of its except
   * its bound.
   *
   * The bound is deferred until later since it may refer to other type
   * parameters that have not been resynthesized yet.  To handle the bound,
   * call [finishTypeParameter].
   */
  TypeParameterElement buildTypeParameter(
      UnlinkedTypeParam serializedTypeParameter) {
    TypeParameterElementImpl typeParameterElement =
        new TypeParameterElementImpl(
            serializedTypeParameter.name, serializedTypeParameter.nameOffset);
    typeParameterElement.type = new TypeParameterTypeImpl(typeParameterElement);
    return typeParameterElement;
  }

  /**
   * Resynthesize a [TopLevelVariableElement] or [FieldElement].
   */
  void buildVariable(UnlinkedVariable serializedVariable,
      [ElementHolder holder]) {
    if (holder == null) {
      TopLevelVariableElementImpl element;
      if (serializedVariable.constExpr != null) {
        ConstTopLevelVariableElementImpl constElement =
            new ConstTopLevelVariableElementImpl(
                serializedVariable.name, serializedVariable.nameOffset);
        element = constElement;
        // TODO(scheglov) share const builder?
        _ConstExprBuilder builder =
            new _ConstExprBuilder(this, serializedVariable.constExpr);
        constElement.constantInitializer = builder.build();
      } else {
        element = new TopLevelVariableElementImpl(
            serializedVariable.name, serializedVariable.nameOffset);
      }
      buildVariableCommonParts(element, serializedVariable);
      unitHolder.addTopLevelVariable(element);
      buildImplicitAccessors(element, unitHolder);
    } else {
      FieldElementImpl element = new FieldElementImpl(
          serializedVariable.name, serializedVariable.nameOffset);
      buildVariableCommonParts(element, serializedVariable);
      element.static = serializedVariable.isStatic;
      holder.addField(element);
      buildImplicitAccessors(element, holder);
      fields[element.name] = element;
    }
  }

  /**
   * Handle the parts that are common to top level variables and fields.
   */
  void buildVariableCommonParts(PropertyInducingElementImpl element,
      UnlinkedVariable serializedVariable) {
    element.type = buildLinkedType(serializedVariable.inferredTypeSlot) ??
        buildType(serializedVariable.type);
    element.const3 = serializedVariable.isConst;
    element.final2 = serializedVariable.isFinal;
    element.hasImplicitType = serializedVariable.type == null;
    element.propagatedType =
        buildLinkedType(serializedVariable.propagatedTypeSlot);
    buildDocumentation(element, serializedVariable.documentationComment);
  }

  /**
   * Finish creating a [TypeParameterElement] by deserializing its bound.
   */
  void finishTypeParameter(UnlinkedTypeParam serializedTypeParameter,
      TypeParameterElementImpl typeParameterElement) {
    if (serializedTypeParameter.bound != null) {
      typeParameterElement.bound = buildType(serializedTypeParameter.bound);
    }
  }

  /**
   * Build the components of an [ElementLocationImpl] for the entity in the
   * given [unit] of the dependency located at [dependencyIndex], and having
   * the given [name].
   */
  List<String> getReferencedLocationComponents(
      int dependencyIndex, int unit, String name) {
    if (dependencyIndex == 0) {
      String referencedLibraryUri = librarySource.uri.toString();
      String partUri;
      if (unit != 0) {
        String uri = unlinkedUnits[0].publicNamespace.parts[unit - 1];
        Source partSource =
            summaryResynthesizer.sourceFactory.resolveUri(librarySource, uri);
        partUri = partSource.uri.toString();
      } else {
        partUri = referencedLibraryUri;
      }
      return <String>[referencedLibraryUri, partUri, name];
    }
    LinkedDependency dependency = linkedLibrary.dependencies[dependencyIndex];
    Source referencedLibrarySource = summaryResynthesizer.sourceFactory
        .resolveUri(librarySource, dependency.uri);
    String referencedLibraryUri = referencedLibrarySource.uri.toString();
    // TODO(paulberry): consider changing Location format so that this is
    // not necessary (2nd string in location should just be the unit
    // number).
    String partUri;
    if (unit != 0) {
      UnlinkedUnit referencedLibraryDefiningUnit =
          summaryResynthesizer._getUnlinkedSummaryOrThrow(referencedLibraryUri);
      String uri =
          referencedLibraryDefiningUnit.publicNamespace.parts[unit - 1];
      Source partSource = summaryResynthesizer.sourceFactory
          .resolveUri(referencedLibrarySource, uri);
      partUri = partSource.uri.toString();
    } else {
      partUri = referencedLibraryUri;
    }
    return <String>[referencedLibraryUri, partUri, name];
  }

  /**
   * Populate [referenceInfos] with the correct information for the current
   * compilation unit.
   */
  void populateReferenceInfos() {
    int numLinkedReferences = linkedUnit.references.length;
    int numUnlinkedReferences = unlinkedUnit.references.length;
    referenceInfos = new List<_ReferenceInfo>(numLinkedReferences);
    for (int i = 0; i < numLinkedReferences; i++) {
      LinkedReference linkedReference = linkedUnit.references[i];
      String name;
      int containingReference;
      if (i < numUnlinkedReferences) {
        name = unlinkedUnit.references[i].name;
        containingReference = unlinkedUnit.references[i].prefixReference;
      } else {
        name = linkedUnit.references[i].name;
        containingReference = linkedUnit.references[i].containingReference;
      }
      ElementHandle element;
      DartType type;
      if (linkedReference.kind == ReferenceKind.unresolved) {
        type = summaryResynthesizer.typeProvider.undefinedType;
      } else if (name == 'dynamic') {
        type = summaryResynthesizer.typeProvider.dynamicType;
      } else if (name == 'void') {
        type = VoidTypeImpl.instance;
      } else {
        List<String> locationComponents;
        if (containingReference != 0 &&
            referenceInfos[containingReference].element is ClassElement) {
          locationComponents = referenceInfos[containingReference]
              .element
              .location
              .components
              .toList();
          locationComponents.add(name);
        } else {
          locationComponents = getReferencedLocationComponents(
              linkedReference.dependency, linkedReference.unit, name);
        }
        ElementLocation location =
            new ElementLocationImpl.con3(locationComponents);
        switch (linkedReference.kind) {
          case ReferenceKind.classOrEnum:
            element = new ClassElementHandle(summaryResynthesizer, location);
            break;
          case ReferenceKind.typedef:
            element = new FunctionTypeAliasElementHandle(
                summaryResynthesizer, location);
            break;
          case ReferenceKind.propertyAccessor:
            assert(location.components.length == 4);
            element = new PropertyAccessorElementHandle(
                summaryResynthesizer, location);
            break;
          case ReferenceKind.method:
            assert(location.components.length == 4);
            element = new MethodElementHandle(summaryResynthesizer, location);
            break;
          default:
            // This is an element that doesn't (yet) need to be referred to
            // directly, so don't bother populating an element for it.
            // TODO(paulberry): add support for more kinds, as needed.
            break;
        }
      }
      referenceInfos[i] = new _ReferenceInfo(
          name, element, type, linkedReference.numTypeParameters);
    }
  }

  /**
   * Populate a [CompilationUnitElement] by deserializing all the elements
   * contained in it.
   */
  void populateUnit(CompilationUnitElementImpl unit, int unitNum) {
    linkedUnit = linkedLibrary.units[unitNum];
    unlinkedUnit = unlinkedUnits[unitNum];
    linkedTypeMap = <int, EntityRef>{};
    for (EntityRef t in linkedUnit.types) {
      linkedTypeMap[t.slot] = t;
    }
    populateReferenceInfos();
    unitHolder = new ElementHolder();
    unlinkedUnit.classes.forEach(buildClass);
    unlinkedUnit.enums.forEach(buildEnum);
    unlinkedUnit.executables.forEach(buildExecutable);
    unlinkedUnit.typedefs.forEach(buildTypedef);
    unlinkedUnit.variables.forEach(buildVariable);
    String absoluteUri = unit.source.uri.toString();
    unit.accessors = unitHolder.accessors;
    unit.enums = unitHolder.enums;
    unit.functions = unitHolder.functions;
    List<FunctionTypeAliasElement> typeAliases = unitHolder.typeAliases;
    for (FunctionTypeAliasElementImpl typeAlias in typeAliases) {
      if (typeAlias.isSynthetic) {
        typeAlias.enclosingElement = unit;
      }
    }
    unit.typeAliases = typeAliases.where((e) => !e.isSynthetic).toList();
    unit.types = unitHolder.types;
    unit.topLevelVariables = unitHolder.topLevelVariables;
    Map<String, Element> elementMap = <String, Element>{};
    for (ClassElement cls in unit.types) {
      elementMap[cls.name] = cls;
    }
    for (ClassElement cls in unit.enums) {
      elementMap[cls.name] = cls;
    }
    for (FunctionTypeAliasElement typeAlias in unit.functionTypeAliases) {
      elementMap[typeAlias.name] = typeAlias;
    }
    for (FunctionElement function in unit.functions) {
      elementMap[function.name] = function;
    }
    for (PropertyAccessorElementImpl accessor in unit.accessors) {
      elementMap[accessor.identifier] = accessor;
    }
    resummarizedElements[absoluteUri] = elementMap;
    unitHolder = null;
    linkedUnit = null;
    unlinkedUnit = null;
    linkedTypeMap = null;
    referenceInfos = null;
  }
}

/**
 * Data structure used during resynthesis to record all the information that is
 * known about how to reserialize a single entry in [LinkedUnit.references]
 * (and its associated entry in [UnlinkedUnit.references], if it exists).
 */
class _ReferenceInfo {
  /**
   * The name of the entity referred to by this reference.
   */
  final String name;

  /**
   * The element referred to by this reference, or `null` if there is no
   * associated element (e.g. because it is a reference to an undefined
   * entity).
   */
  final Element element;

  /**
   * If this reference refers to a non-generic type, the type it refers to.
   * Otherwise `null`.
   */
  DartType type;

  /**
   * The number of type parameters accepted by the entity referred to by this
   * reference, or zero if it doesn't accept any type parameters.
   */
  final int numTypeParameters;

  /**
   * Create a new [_ReferenceInfo] object referring to an element called [name]
   * via the element handle [elementHandle], and having [numTypeParameters]
   * type parameters.
   *
   * For the special types `dynamic` and `void`, [specialType] should point to
   * the type itself.  Otherwise, pass `null` and the type will be computed
   * when appropriate.
   */
  _ReferenceInfo(
      this.name, this.element, DartType specialType, this.numTypeParameters) {
    if (specialType != null) {
      type = specialType;
    } else if (numTypeParameters == 0) {
      // We can precompute the type because it doesn't depend on type
      // parameters.
      type = _buildType(null, null);
    }
  }

  /**
   * Build a [DartType] corresponding to the result of applying some type
   * arguments to the entity referred to by this [_ReferenceInfo].  The type
   * arguments are retrieved by calling [getTypeArgument].
   *
   * If [implicitFunctionTypeIndices] is not empty, a [DartType] should be
   * created which refers to a function type implicitly defined by one of the
   * element's parameters.  [implicitFunctionTypeIndices] is interpreted as in
   * [EntityRef.implicitFunctionTypeIndices].
   *
   * If the entity referred to by this [_ReferenceInfo] is not a type, `null`
   * is returned.
   */
  DartType buildType(
      DartType getTypeArgument(int i), List<int> implicitFunctionTypeIndices) {
    DartType result =
        (numTypeParameters == 0 && implicitFunctionTypeIndices.isEmpty)
            ? type
            : _buildType(getTypeArgument, implicitFunctionTypeIndices);
    if (result == null) {
      // TODO(paulberry): figure out how to handle this case (which should
      // only occur in the event of erroneous code).
      throw new UnimplementedError();
    }
    return result;
  }

  /**
   * If this reference refers to a type, build a [DartType] which instantiates
   * it with type arguments returned by [getTypeArgument].  Otherwise return
   * `null`.
   *
   * If [implicitFunctionTypeIndices] is not null, a [DartType] should be
   * created which refers to a function type implicitly defined by one of the
   * element's parameters.  [implicitFunctionTypeIndices] is interpreted as in
   * [EntityRef.implicitFunctionTypeIndices].
   */
  DartType _buildType(
      DartType getTypeArgument(int i), List<int> implicitFunctionTypeIndices) {
    List<DartType> typeArguments = const <DartType>[];
    if (numTypeParameters != 0) {
      typeArguments = <DartType>[];
      for (int i = 0; i < numTypeParameters; i++) {
        typeArguments.add(getTypeArgument(i));
      }
    }
    ElementHandle element = this.element; // To allow type promotion
    if (element is ClassElementHandle) {
      return new InterfaceTypeImpl.elementWithNameAndArgs(
          element, name, typeArguments);
    } else if (element is FunctionTypeAliasElementHandle) {
      return new FunctionTypeImpl.elementWithNameAndArgs(
          element, name, typeArguments, typeArguments.isNotEmpty);
    } else if (element is FunctionTypedElement &&
        implicitFunctionTypeIndices != null) {
      FunctionTypedElementComputer computer = () {
        FunctionTypedElement element = this.element;
        for (int index in implicitFunctionTypeIndices) {
          element = element.parameters[index].type.element;
        }
        return element;
      };
      // TODO(paulberry): Is it a bug that we have to pass `false` for
      // isInstantiated?
      return new DeferredFunctionTypeImpl(computer, null, typeArguments, false);
    } else {
      return null;
    }
  }
}
