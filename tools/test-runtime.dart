#!/usr/bin/env dart
// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(ager): Get rid of this version of test.dart when we don't have
// to worry about the special runtime checkout anymore.
// This file is identical to test.dart with test suites in the
// directories samples, client, compiler, and utils removed.

library test;

import "dart:io";
import "testing/dart/test_runner.dart";
import "testing/dart/test_options.dart";
import "testing/dart/test_suite.dart";
import "testing/dart/http_server.dart";
import "testing/dart/utils.dart";
import "testing/dart/test_progress.dart";

import "../tests/co19/test_config.dart";
import "../runtime/tests/vm/test_config.dart";

/**
 * The directories that contain test suites which follow the conventions
 * required by [StandardTestSuite]'s forDirectory constructor.
 * New test suites should follow this convention because it makes it much
 * simpler to add them to test.dart.  Existing test suites should be
 * moved to here, if possible.
*/
final TEST_SUITE_DIRECTORIES = [
  new Path('runtime/tests/vm'),
  new Path('tests/corelib'),
  new Path('tests/isolate'),
  new Path('tests/language'),
  new Path('tests/lib'),
  new Path('tests/standalone'),
  new Path('tests/utils'),
];

main() {
  var startTime = new DateTime.now();
  var optionsParser = new TestOptionsParser();
  List<Map> configurations = optionsParser.parse(new Options().arguments);
  if (configurations == null) return;

  // Extract global options from first configuration.
  var firstConf = configurations[0];
  Map<String, RegExp> selectors = firstConf['selectors'];
  var maxProcesses = firstConf['tasks'];
  var progressIndicator = firstConf['progress'];
  var verbose = firstConf['verbose'];
  var printTiming = firstConf['time'];
  var listTests = firstConf['list'];

  if (!firstConf['append_logs'])  {
    var file = new File(TestUtils.flakyFileName());
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
  // Print the configurations being run by this execution of
  // test.dart. However, don't do it if the silent progress indicator
  // is used. This is only needed because of the junit tests.
  if (progressIndicator != 'silent') {
    List output_words = configurations.length > 1 ?
        ['Test configurations:'] : ['Test configuration:'];
    for (Map conf in configurations) {
      List settings = ['compiler', 'runtime', 'mode', 'arch']
          .map((name) => conf[name]).toList();
      if (conf['checked']) settings.add('checked');
      output_words.add(settings.join('_'));
    }
    print(output_words.join(' '));
  }

  var testSuites = new List<TestSuite>();
  for (var conf in configurations) {
    if (selectors.containsKey('co19')) {
      testSuites.add(new Co19TestSuite(conf));
    }

    if (conf['runtime'] == 'vm' && selectors.containsKey('vm')) {
      // vm tests contain both cc tests (added here) and dart tests (added in
      // [TEST_SUITE_DIRECTORIES]).
      testSuites.add(new VMTestSuite(conf));
    }

    for (final testSuiteDir in TEST_SUITE_DIRECTORIES) {
      final name = testSuiteDir.filename;
      if (selectors.containsKey(name)) {
        testSuites.add(new StandardTestSuite.forDirectory(conf, testSuiteDir));
      }
    }
  }

  void allTestsFinished() {
    DebugLogger.close();
  }

  var maxBrowserProcesses = maxProcesses;

  var eventListener = [];
  if (progressIndicator != 'silent') {
    var printFailures = true;
    var formatter = new Formatter();
    if (progressIndicator == 'color') {
      progressIndicator = 'compact';
      formatter = new ColorFormatter();
    }
    if (progressIndicator == 'diff') {
      progressIndicator = 'compact';
      formatter = new ColorFormatter();
      printFailures = false;
      eventListener.add(new StatusFileUpdatePrinter());
    }
    eventListener.add(new SummaryPrinter());
    eventListener.add(new FlakyLogWriter());
    if (printFailures) {
      eventListener.add(new TestFailurePrinter(formatter));
    }
    eventListener.add(new ProgressIndicator.fromName(progressIndicator,
                                                     startTime,
                                                     formatter));
    if (printTiming) {
      eventListener.add(new TimingPrinter(startTime));
    }
    eventListener.add(new SkippedCompilationsPrinter());
    eventListener.add(new LeftOverTempDirPrinter());
  }
  eventListener.add(new ExitCodeSetter());

  // Start process queue.
  new ProcessQueue(
      maxProcesses,
      maxBrowserProcesses,
      startTime,
      testSuites,
      eventListener,
      allTestsFinished,
      verbose,
      listTests);
}