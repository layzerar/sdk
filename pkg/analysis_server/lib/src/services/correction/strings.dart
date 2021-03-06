// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.src.correction.strings;

import 'dart:math';

/**
 * "$"
 */
const int CHAR_DOLLAR = 0x24;

/**
 * "."
 */
const int CHAR_DOT = 0x2E;

/**
 * "_"
 */
const int CHAR_UNDERSCORE = 0x5F;

String capitalize(String str) {
  if (isEmpty(str)) {
    return str;
  }
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

int compareStrings(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

int countLeadingWhitespaces(String str) {
  int i = 0;
  for (; i < str.length; i++) {
    int c = str.codeUnitAt(i);
    if (!isWhitespace(c)) {
      break;
    }
  }
  return i;
}

/**
 * Counts how many times [sub] appears in [str].
 */
int countMatches(String str, String sub) {
  if (isEmpty(str) || isEmpty(sub)) {
    return 0;
  }
  int count = 0;
  int idx = 0;
  while ((idx = str.indexOf(sub, idx)) != -1) {
    count++;
    idx += sub.length;
  }
  return count;
}

int countTrailingWhitespaces(String str) {
  int i = 0;
  for (; i < str.length; i++) {
    int c = str.codeUnitAt(str.length - 1 - i);
    if (!isWhitespace(c)) {
      break;
    }
  }
  return i;
}

/**
 * Returns the number of characters common to the end of [a] and the start
 * of [b].
 */
int findCommonOverlap(String a, String b) {
  int a_length = a.length;
  int b_length = b.length;
  // all empty
  if (a_length == 0 || b_length == 0) {
    return 0;
  }
  // truncate
  if (a_length > b_length) {
    a = a.substring(a_length - b_length);
  } else if (a_length < b_length) {
    b = b.substring(0, a_length);
  }
  int text_length = min(a_length, b_length);
  // the worst case
  if (a == b) {
    return text_length;
  }
  // increase common length one by one
  int length = 0;
  while (length < text_length) {
    if (a.codeUnitAt(text_length - 1 - length) != b.codeUnitAt(length)) {
      break;
    }
    length++;
  }
  return length;
}

/**
 * Return the number of characters common to the start of [a] and [b].
 */
int findCommonPrefix(String a, String b) {
  int n = min(a.length, b.length);
  for (int i = 0; i < n; i++) {
    if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
      return i;
    }
  }
  return n;
}

/**
 * Return the number of characters common to the end of [a] and [b].
 */
int findCommonSuffix(String a, String b) {
  int a_length = a.length;
  int b_length = b.length;
  int n = min(a_length, b_length);
  for (int i = 1; i <= n; i++) {
    if (a.codeUnitAt(a_length - i) != b.codeUnitAt(b_length - i)) {
      return i - 1;
    }
  }
  return n;
}

/**
 * Returns a list of words for the given camel case string.
 *
 * 'getCamelWords' => ['get', 'Camel', 'Words']
 * 'getHTMLText' => ['get', 'HTML', 'Text']
 */
List<String> getCamelWords(String str) {
  if (str == null || str.isEmpty) {
    return <String>[];
  }
  List<String> parts = <String>[];
  bool wasLowerCase = false;
  bool wasUpperCase = false;
  int wordStart = 0;
  for (int i = 0; i < str.length; i++) {
    int c = str.codeUnitAt(i);
    var newLowerCase = isLowerCase(c);
    var newUpperCase = isUpperCase(c);
    // myWord
    // | ^
    if (wasLowerCase && newUpperCase) {
      parts.add(str.substring(wordStart, i));
      wordStart = i;
    }
    // myHTMLText
    //   |   ^
    if (wasUpperCase &&
        newUpperCase &&
        i + 1 < str.length &&
        isLowerCase(str.codeUnitAt(i + 1))) {
      parts.add(str.substring(wordStart, i));
      wordStart = i;
    }
    wasLowerCase = newLowerCase;
    wasUpperCase = newUpperCase;
  }
  parts.add(str.substring(wordStart));
  return parts;
}

/**
 * Checks if [str] is `null`, empty or is whitespace.
 */
bool isBlank(String str) {
  if (str == null) {
    return true;
  }
  if (str.isEmpty) {
    return true;
  }
  return str.codeUnits.every(isSpace);
}

bool isDigit(int c) {
  return c >= 0x30 && c <= 0x39;
}

bool isEmpty(String str) {
  return str == null || str.isEmpty;
}

bool isEOL(int c) {
  return c == 0x0D || c == 0x0A;
}

bool isLetter(int c) {
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
}

bool isLetterOrDigit(int c) {
  return isLetter(c) || isDigit(c);
}

bool isLowerCase(int c) {
  return c >= 0x61 && c <= 0x7A;
}

bool isSpace(int c) => c == 0x20 || c == 0x09;

bool isUpperCase(int c) {
  return c >= 0x41 && c <= 0x5A;
}

bool isWhitespace(int c) {
  return isSpace(c) || isEOL(c);
}

String remove(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  return str.replaceAll(remove, '');
}

String removeEnd(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  if (str.endsWith(remove)) {
    return str.substring(0, str.length - remove.length);
  }
  return str;
}

String removeStart(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  if (str.startsWith(remove)) {
    return str.substring(remove.length);
  }
  return str;
}

String repeat(String s, int n) {
  StringBuffer sb = new StringBuffer();
  for (int i = 0; i < n; i++) {
    sb.write(s);
  }
  return sb.toString();
}

/**
 * Gets the substring after the last occurrence of a separator.
 * The separator is not returned.
 */
String substringAfterLast(String str, String separator) {
  if (isEmpty(str)) {
    return str;
  }
  if (isEmpty(separator)) {
    return '';
  }
  int pos = str.lastIndexOf(separator);
  if (pos == -1) {
    return str;
  }
  return str.substring(pos + separator.length);
}
