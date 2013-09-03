// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:expect/expect.dart';
import 'memory_source_file_helper.dart';

import '../../../sdk/lib/_internal/compiler/compiler.dart'
       show Diagnostic;

import 'dart:json';

main() {
  Uri script = currentDirectory.resolve(nativeToUriPath(Platform.script));
  Uri libraryRoot = script.resolve('../../../sdk/');
  Uri packageRoot = script.resolve('./packages/');

  MemorySourceFileProvider.MEMORY_SOURCE_FILES = MEMORY_SOURCE_FILES;
  var provider = new MemorySourceFileProvider();
  var diagnostics = [];
  void diagnosticHandler(Uri uri, int begin, int end,
                         String message, Diagnostic kind) {
    if (kind == Diagnostic.VERBOSE_INFO) {
      return;
    }
    diagnostics.add('$uri:$begin:$end:$message:$kind');
  }

  Compiler compiler = new Compiler(provider.readStringFromUri,
                                   (name, extension) => null,
                                   diagnosticHandler,
                                   libraryRoot,
                                   packageRoot,
                                   ['--analyze-only']);
  compiler.run(Uri.parse('memory:main.dart'));
  diagnostics.sort();
  var expected = [
      'memory:exporter.dart:43:47:Info: "function(hest)" is defined here.:info',
      'memory:library.dart:14:19:Info: "class(Fisk)" is (re)exported by '
      'multiple libraries.:info',
      'memory:library.dart:30:34:Info: "function(fisk)" is (re)exported by '
      'multiple libraries.:info',
      'memory:library.dart:41:45:Info: "function(hest)" is defined here.'
      ':info',
      'memory:main.dart:0:22:Info: "class(Fisk)" is imported here.:info',
      'memory:main.dart:0:22:Info: "function(fisk)" is imported here.:info',
      'memory:main.dart:0:22:Info: "function(hest)" is imported here.:info',
      'memory:main.dart:23:46:Info: "class(Fisk)" is imported here.:info',
      'memory:main.dart:23:46:Info: "function(fisk)" is imported here.:info',
      'memory:main.dart:23:46:Info: "function(hest)" is imported here.:info',
      'memory:main.dart:59:63:Warning: Duplicate import of "Fisk".:warning',
      'memory:main.dart:76:80:Error: Duplicate import of "fisk".:error',
      'memory:main.dart:86:90:Error: Duplicate import of "hest".:error'
  ];
  Expect.listEquals(expected, diagnostics);
  Expect.isTrue(compiler.compilationFailed);
}

const Map MEMORY_SOURCE_FILES = const {
  'main.dart': """
import 'library.dart';
import 'exporter.dart';

main() {
  Fisk x = null;
  fisk();
  hest();
}
""",
  'library.dart': """
library lib;

class Fisk {
}

fisk() {}

hest() {}
""",
  'exporter.dart': """
library exporter;

export 'library.dart';

hest() {}
""",
};