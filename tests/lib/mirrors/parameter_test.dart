// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Test of [ParameterMirror].
library test.parameter_test;

@MirrorsUsed(targets: 'test.parameter_test', override: '*')
import 'dart:mirrors';

import 'package:expect/expect.dart';
import 'stringify.dart';

class B {
  B();
  B.foo(int x);
  B.bar(int z, x);

  // TODO(6490): Currently only supported by the VM.
  B.baz(final int x, int y, final int z);
  B.qux(int x, [int y= 3 + 1]);
  B.quux(int x, {String str: "foo"});
  B.corge({int x: 3 * 17, String str: "bar"});

  var _x;
  get x =>  _x;
  set x(final value) { _x = value; }

  grault([int x]);
  garply({int y});
  waldo(int z);
}

main() {
  ClassMirror cm = reflectClass(B);
  Map<Symbol, MethodMirror> constructors = cm.constructors;

  List<Symbol> constructorKeys = [
      const Symbol('B'), const Symbol('B.bar'), const Symbol('B.baz'),
      const Symbol('B.foo'), const Symbol('B.quux'), const Symbol('B.qux'),
      const Symbol('B.corge')];
  Expect.setEquals(constructorKeys, constructors.keys);

  MethodMirror unnamedConstructor = constructors[const Symbol('B')];
  expect('Method(s(B) in s(B), constructor)', unnamedConstructor);
  expect('[]', unnamedConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         unnamedConstructor.returnType);

  MethodMirror fooConstructor = constructors[const Symbol('B.foo')];
  expect('Method(s(B.foo) in s(B), constructor)', fooConstructor);
  expect('[Parameter(s(x) in s(B.foo),'
         ' type = Class(s(int) in s(dart.core), top-level))]',
         fooConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         fooConstructor.returnType);

  MethodMirror barConstructor = constructors[const Symbol('B.bar')];
  expect('Method(s(B.bar) in s(B), constructor)', barConstructor);
  expect('[Parameter(s(z) in s(B.bar),'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(x) in s(B.bar),'
         ' type = Type(s(dynamic), top-level))]',
         barConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         barConstructor.returnType);

  MethodMirror bazConstructor = constructors[const Symbol('B.baz')];
  expect('Method(s(B.baz) in s(B), constructor)', bazConstructor);
  expect('[Parameter(s(x) in s(B.baz), final,'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(y) in s(B.baz),'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(z) in s(B.baz), final,'
         ' type = Class(s(int) in s(dart.core), top-level))]',
         bazConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         bazConstructor.returnType);

  MethodMirror quxConstructor = constructors[const Symbol('B.qux')];
  expect('Method(s(B.qux) in s(B), constructor)', quxConstructor);
  expect('[Parameter(s(x) in s(B.qux),'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(y) in s(B.qux), optional,'
         ' value = Instance(value = 4),'
         ' type = Class(s(int) in s(dart.core), top-level))]',
         quxConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         quxConstructor.returnType);

  MethodMirror quuxConstructor = constructors[const Symbol('B.quux')];
  expect('Method(s(B.quux) in s(B), constructor)', quuxConstructor);
  expect('[Parameter(s(x) in s(B.quux),'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(str) in s(B.quux), optional, named,'
         ' value = Instance(value = foo),'
         ' type = Class(s(String) in s(dart.core), top-level))]',
         quuxConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         quuxConstructor.returnType);

  MethodMirror corgeConstructor = constructors[const Symbol('B.corge')];
  expect('Method(s(B.corge) in s(B), constructor)', corgeConstructor);
  expect('[Parameter(s(x) in s(B.corge), optional, named,'
         ' value = Instance(value = 51),'
         ' type = Class(s(int) in s(dart.core), top-level)), '
         'Parameter(s(str) in s(B.corge), optional, named,'
         ' value = Instance(value = bar),'
         ' type = Class(s(String) in s(dart.core), top-level))]',
         corgeConstructor.parameters);
  expect('Class(s(B) in s(test.parameter_test), top-level)',
         corgeConstructor.returnType);

  MethodMirror xGetter = cm.getters[const Symbol('x')];
  expect('Method(s(x) in s(B), getter)', xGetter);
  expect('[]', xGetter.parameters);

  MethodMirror xSetter = cm.setters[const Symbol('x=')];
  expect('Method(s(x=) in s(B), setter)', xSetter);
  expect('[Parameter(s(value) in s(x=), final,'
         ' type = Type(s(dynamic), top-level))]',
         xSetter.parameters);

  MethodMirror grault = cm.members[const Symbol("grault")];
  expect('Method(s(grault) in s(B))', grault);
  expect('[Parameter(s(x) in s(grault), optional,'
         ' type = Class(s(int) in s(dart.core), top-level))]',
         grault.parameters);
  expect('Instance(value = <null>)', grault.parameters[0].defaultValue);

  MethodMirror garply = cm.members[const Symbol("garply")];
  expect('Method(s(garply) in s(B))', garply);
  expect('[Parameter(s(y) in s(garply), optional, named,'
         ' type = Class(s(int) in s(dart.core), top-level))]',
         garply.parameters);
  expect('Instance(value = <null>)', garply.parameters[0].defaultValue);

  MethodMirror waldo = cm.members[const Symbol("waldo")];
  expect('Method(s(waldo) in s(B))', waldo);
  expect('[Parameter(s(z) in s(waldo),' 
         ' type = Class(s(int) in s(dart.core), top-level))]',
         waldo.parameters);
  expect('<null>', waldo.parameters[0].defaultValue);
}