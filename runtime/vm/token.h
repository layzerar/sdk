// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef VM_TOKEN_H_
#define VM_TOKEN_H_

#include "platform/assert.h"
#include "vm/allocation.h"

namespace dart {

//  Operator precedence table
//
//  14  multiplicative  * / ~/ %
//  13  additive        + -
//  12  shift           << >>
//  11  bitwise and     &
//  10  bitwise xor     ^
//   9  bitwise or      |
//   8  relational      >= > <= < is as
//   7  equality        == != === !==
//   6  logical and     &&
//   5  logical or      ||
//   4  null check      ??
//   3  conditional     ?
//   2  assignment      = *= /= ~/= %= += -= <<= >>= &= ^= |= ??=
//   1  comma           ,


// Token definitions.
// Some operator tokens appear in blocks, e.g. assignment operators.
// There is code that depends on the values within a block to be
// contiguous, and on the order of values.
#define DART_TOKEN_LIST(TOK)                                                   \
  TOK(kEOS, "", 0, kNoAttribute)                                               \
                                                                               \
  TOK(kLPAREN, "(", 0, kNoAttribute)                                           \
  TOK(kRPAREN, ")", 0, kNoAttribute)                                           \
  TOK(kLBRACK, "[", 0, kNoAttribute)                                           \
  TOK(kRBRACK, "]", 0, kNoAttribute)                                           \
  TOK(kLBRACE, "{", 0, kNoAttribute)                                           \
  TOK(kRBRACE, "}", 0, kNoAttribute)                                           \
  TOK(kARROW, "=>", 0, kNoAttribute)                                           \
  TOK(kCOLON,  ":", 0, kNoAttribute)                                           \
  TOK(kSEMICOLON, ";", 0, kNoAttribute)                                        \
  TOK(kPERIOD, ".", 0, kNoAttribute)                                           \
  TOK(kQM_PERIOD, "?.", 0, kNoAttribute)                                       \
  TOK(kINCR,   "++", 0, kNoAttribute)                                          \
  TOK(kDECR,   "--", 0, kNoAttribute)                                          \
                                                                               \
  /* Assignment operators.                            */                       \
  /* Please update IsAssignmentOperator() if you make */                       \
  /* any changes to this block.                       */                       \
  TOK(kASSIGN, "=", 2, kNoAttribute)                                           \
  TOK(kASSIGN_OR, "|=", 2, kNoAttribute)                                       \
  TOK(kASSIGN_XOR, "^=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_AND, "&=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_SHL, "<<=", 2, kNoAttribute)                                     \
  TOK(kASSIGN_SHR, ">>=", 2, kNoAttribute)                                     \
  TOK(kASSIGN_ADD, "+=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_SUB, "-=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_MUL, "*=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_TRUNCDIV, "~/=", 2, kNoAttribute)                                \
  TOK(kASSIGN_DIV, "/=", 2, kNoAttribute)                                      \
  TOK(kASSIGN_MOD, "%=", 2, kNoAttribute)                                      \
  /* Avoid trigraph ??= below. */                                              \
  TOK(kASSIGN_COND, "?\?=", 2, kNoAttribute)                                   \
                                                                               \
  TOK(kCASCADE, "..", 2, kNoAttribute)                                         \
                                                                               \
  TOK(kCOMMA, ",", 1, kNoAttribute)                                            \
  TOK(kOR, "||", 5, kNoAttribute)                                              \
  TOK(kAND, "&&", 6, kNoAttribute)                                             \
  TOK(kBIT_OR, "|", 9, kNoAttribute)                                           \
  TOK(kBIT_XOR, "^", 10, kNoAttribute)                                         \
  TOK(kBIT_AND, "&", 11, kNoAttribute)                                         \
  TOK(kBIT_NOT, "~", 0, kNoAttribute)                                          \
                                                                               \
  /* Shift operators. */                                                       \
  TOK(kSHL, "<<", 12, kNoAttribute)                                            \
  TOK(kSHR, ">>", 12, kNoAttribute)                                            \
                                                                               \
  /* Additive operators. */                                                    \
  TOK(kADD, "+", 13, kNoAttribute)                                             \
  TOK(kSUB, "-", 13, kNoAttribute)                                             \
                                                                               \
  /* Multiplicative operators */                                               \
  TOK(kMUL, "*", 14, kNoAttribute)                                             \
  TOK(kDIV, "/", 14, kNoAttribute)                                             \
  TOK(kTRUNCDIV, "~/", 14, kNoAttribute)                                       \
  TOK(kMOD, "%", 14, kNoAttribute)                                             \
                                                                               \
  TOK(kNOT, "!", 0, kNoAttribute)                                              \
  TOK(kCONDITIONAL, "?", 3, kNoAttribute)                                      \
  TOK(kIFNULL, "??", 4, kNoAttribute)                                          \
                                                                               \
  /* Equality operators.                             */                        \
  /* Please update IsEqualityOperator() if you make  */                        \
  /* any changes to this block.                      */                        \
  TOK(kEQ, "==", 7, kNoAttribute)                                              \
  TOK(kNE, "!=", 7, kNoAttribute)                                              \
  TOK(kEQ_STRICT, "===", 7, kNoAttribute)                                      \
  TOK(kNE_STRICT, "!==", 7, kNoAttribute)                                      \
                                                                               \
  /* Relational operators.                             */                      \
  /* Please update IsRelationalOperator() if you make  */                      \
  /* any changes to this block.                        */                      \
  TOK(kLT, "<", 8, kNoAttribute)                                               \
  TOK(kGT, ">", 8, kNoAttribute)                                               \
  TOK(kLTE, "<=", 8, kNoAttribute)                                             \
  TOK(kGTE, ">=", 8, kNoAttribute)                                             \
                                                                               \
  /* Internal token for !(expr is Type) negative type test operator */         \
  TOK(kISNOT, "", 11, kNoAttribute)                                            \
                                                                               \
  TOK(kINDEX, "[]", 0, kNoAttribute)                                           \
  TOK(kASSIGN_INDEX, "[]=", 0, kNoAttribute)                                   \
  TOK(kNEGATE, "unary-", 0, kNoAttribute)                                      \
                                                                               \
  TOK(kIDENT, "", 0, kNoAttribute)                                             \
  TOK(kSTRING, "", 0, kNoAttribute)                                            \
  TOK(kINTEGER, "", 0, kNoAttribute)                                           \
  TOK(kDOUBLE, "", 0, kNoAttribute)                                            \
                                                                               \
  TOK(kINTERPOL_VAR, "$", 0, kNoAttribute)                                     \
  TOK(kINTERPOL_START, "${", 0, kNoAttribute)                                  \
  TOK(kINTERPOL_END, "}", 0, kNoAttribute)                                     \
                                                                               \
  TOK(kAT, "@", 0, kNoAttribute)                                               \
  TOK(kHASH, "#", 0, kNoAttribute)                                             \
                                                                               \
  TOK(kNEWLINE, "\n", 0, kNoAttribute)                                         \
  TOK(kWHITESP, "", 0, kNoAttribute)                                           \
  TOK(kERROR, "", 0, kNoAttribute)                                             \
  TOK(kILLEGAL, "", 0, kNoAttribute)                                           \
                                                                               \
  /* Support for Dart scripts. */                                              \
  TOK(kSCRIPTTAG, "#!", 0, kNoAttribute)                                       \
                                                                               \
  /* Support for optimized code */                                             \
  TOK(kREM, "", 0, kNoAttribute)                                               \

// List of keywords. The list must be alphabetically ordered. The
// keyword recognition code depends on the ordering.
// If you add a keyword at the beginning or end of this list, make sure
// to update kFirstKeyword and kLastKeyword below.
#define DART_KEYWORD_LIST(KW)                                                  \
  KW(kABSTRACT, "abstract", 0, kPseudoKeyword) /* == kFirstKeyword */          \
  KW(kAS, "as", 11, kPseudoKeyword)                                            \
  KW(kASSERT, "assert", 11, kKeyword)                                          \
  KW(kBREAK, "break", 0, kKeyword)                                             \
  KW(kCASE, "case", 0, kKeyword)                                               \
  KW(kCATCH, "catch", 0, kKeyword)                                             \
  KW(kCLASS, "class", 0, kKeyword)                                             \
  KW(kCONST, "const", 0, kKeyword)                                             \
  KW(kCONTINUE, "continue", 0, kKeyword)                                       \
  KW(kDEFAULT, "default", 0, kKeyword)                                         \
  KW(kDO, "do", 0, kKeyword)                                                   \
  KW(kELSE, "else", 0, kKeyword)                                               \
  KW(kENUM, "enum", 0, kKeyword)                                               \
  KW(kEXPORT, "export", 0, kPseudoKeyword)                                     \
  KW(kEXTENDS, "extends", 0, kKeyword)                                         \
  KW(kEXTERNAL, "external", 0, kPseudoKeyword)                                 \
  KW(kFACTORY, "factory", 0, kPseudoKeyword)                                   \
  KW(kFALSE, "false", 0, kKeyword)                                             \
  KW(kFINAL, "final", 0, kKeyword)                                             \
  KW(kFINALLY, "finally", 0, kKeyword)                                         \
  KW(kFOR, "for", 0, kKeyword)                                                 \
  KW(kGET, "get", 0, kPseudoKeyword)                                           \
  KW(kIF, "if", 0, kKeyword)                                                   \
  KW(kIMPLEMENTS, "implements", 0, kPseudoKeyword)                             \
  KW(kIMPORT, "import", 0, kPseudoKeyword)                                     \
  KW(kIN, "in", 0, kKeyword)                                                   \
  KW(kIS, "is", 11, kKeyword)                                                  \
  KW(kLIBRARY, "library", 0, kPseudoKeyword)                                   \
  KW(kNEW, "new", 0, kKeyword)                                                 \
  KW(kNULL, "null", 0, kKeyword)                                               \
  KW(kOPERATOR, "operator", 0, kPseudoKeyword)                                 \
  KW(kPART, "part", 0, kPseudoKeyword)                                         \
  KW(kRETHROW, "rethrow", 0, kKeyword)                                         \
  KW(kRETURN, "return", 0, kKeyword)                                           \
  KW(kSET, "set", 0, kPseudoKeyword)                                           \
  KW(kSTATIC, "static", 0, kPseudoKeyword)                                     \
  KW(kSUPER, "super", 0, kKeyword)                                             \
  KW(kSWITCH, "switch", 0, kKeyword)                                           \
  KW(kTHIS, "this", 0, kKeyword)                                               \
  KW(kTHROW, "throw", 0, kKeyword)                                             \
  KW(kTRUE, "true", 0, kKeyword)                                               \
  KW(kTRY, "try", 0, kKeyword)                                                 \
  KW(kTYPEDEF, "typedef", 0, kPseudoKeyword)                                   \
  KW(kVAR, "var", 0, kKeyword)                                                 \
  KW(kVOID, "void", 0, kKeyword)                                               \
  KW(kWHILE, "while", 0, kKeyword)                                             \
  KW(kWITH, "with", 0, kKeyword) /* == kLastKeyword */

class String;

// The token space is organized as follows:
//
// Sentinel values start at -1 and move towards negative infinity:
// kNoSourcePos                -> -1
// ClassifyingTokenPositions 1 -> -1 - 1
// ClassifyingTokenPositions N -> -1 - N
//
// Synthetically created AstNodes are given real source positions but encoded
// as negative numbers from [kSmiMin32, -1 - N]. For example:
//
// A source position of 0 in a synthetic AstNode would be encoded as -2 - N.
// A source position of 1 in a synthetic AstNode would be encoded as -3 - N.
//
// All other AstNodes are given real source positions encoded as positive
// integers.
//
// This organization allows for ~1 billion token positions.
//
// NOTE: While token positions are passed around as an intptr_t they are encoded
// into the snapshot as an int32_t.

// These token positions are used to classify instructions that can't be
// directly tied to an actual source position.
#define CLASSIFYING_TOKEN_POSITIONS(V)                                         \
    V(Private, -2)                                                             \
    V(Box, -3)                                                                 \
    V(ParallelMove, -4)                                                        \
    V(TempMove, -5)                                                            \
    V(Constant, -6)                                                            \
    V(PushArgument, -7)                                                        \
    V(ControlFlow, -8)                                                         \
    V(Context, -9)                                                             \
    V(MethodExtractor, -10)                                                    \
    V(Last, -11)   // Always keep this at the end.


class ClassifyingTokenPositions : public AllStatic {
 public:
#define DEFINE_VALUES(name, value)                                             \
  static const intptr_t k##name = value;
  CLASSIFYING_TOKEN_POSITIONS(DEFINE_VALUES);
#undef DEFINE_VALUES

  static const char* ToCString(intptr_t token_pos);
};


class Token {
 public:
#define T(t, s, p, a) t,
  enum Kind {
    DART_TOKEN_LIST(T)
    DART_KEYWORD_LIST(T)
    kNumTokens
  };
#undef T

  enum Attribute {
    kNoAttribute     = 0,
    kKeyword         = 1 << 0,
    kPseudoKeyword   = 1 << 1,
  };

  // Token position constants.
  static const intptr_t kNoSourcePos = -1;
  static const intptr_t kMinSourcePos = 0;
  static const intptr_t kMaxSourcePos =
      kSmiMax32 - (-ClassifyingTokenPositions::kLast) - 2;

  // Is |token_pos| a classifying sentinel source position?
  static bool IsClassifying(intptr_t token_pos) {
    return (token_pos >= ClassifyingTokenPositions::kPrivate) &&
           (token_pos <= ClassifyingTokenPositions::kLast);
  }

  // Is |token_pos| a synthetic source position?
  static bool IsSynthetic(intptr_t token_pos) {
    if (token_pos >= kMinSourcePos) {
      return false;
    }
    if (token_pos < ClassifyingTokenPositions::kLast) {
      return true;
    }
    return false;
  }

  // Is |token_pos| the no source position sentinel?
  static bool IsNoSource(intptr_t token_pos) {
    return token_pos == kNoSourcePos;
  }

  // Is |token_pos| a real source position?
  static bool IsReal(intptr_t token_pos) {
    return token_pos >= kMinSourcePos;
  }

  // Is |token_pos| a source position?
  static bool IsSourcePosition(intptr_t token_pos) {
    return IsReal(token_pos) || IsNoSource(token_pos) || IsSynthetic(token_pos);
  }

  // Is |token_pos| a debug pause source position?
  static bool IsDebugPause(intptr_t token_pos) {
    return IsReal(token_pos);
  }

  // Encode |token_pos| into a synthetic source position.
  static intptr_t ToSynthetic(intptr_t token_pos) {
    if (IsClassifying(token_pos) || IsNoSource(token_pos)) {
      return token_pos;
    }
    if (IsSynthetic(token_pos)) {
      return token_pos;
    }
    ASSERT(!IsSynthetic(token_pos));
    const intptr_t value = (ClassifyingTokenPositions::kLast - 1) - token_pos;
    ASSERT(IsSynthetic(value));
    ASSERT(value < ClassifyingTokenPositions::kLast);
    return value;
  }

  // Decode |token_pos| from a synthetic source position.
  static intptr_t FromSynthetic(intptr_t token_pos) {
    if (IsClassifying(token_pos) || IsNoSource(token_pos)) {
      return token_pos;
    }
    if (!IsSynthetic(token_pos)) {
      return token_pos;
    }
    ASSERT(IsSynthetic(token_pos));
    const intptr_t value = -token_pos + (ClassifyingTokenPositions::kLast - 1);
    ASSERT(!IsSynthetic(value));
    return value;
  }

  static const Kind kFirstKeyword = kABSTRACT;
  static const Kind kLastKeyword = kWITH;
  static const int kNumKeywords = kLastKeyword - kFirstKeyword + 1;

  static bool IsAssignmentOperator(Kind tok) {
    return kASSIGN <= tok && tok <= kASSIGN_COND;
  }

  static bool IsRelationalOperator(Kind tok) {
    return kLT <= tok && tok <= kGTE;
  }

  static bool IsEqualityOperator(Kind tok) {
    return kEQ <= tok && tok <= kNE_STRICT;
  }

  static bool IsStrictEqualityOperator(Kind tok) {
    return (tok == kEQ_STRICT) || (tok == kNE_STRICT);
  }

  static bool IsTypeTestOperator(Kind tok) {
    return (tok == kIS) || (tok == kISNOT);
  }

  static bool IsTypeCastOperator(Kind tok) {
    return tok == kAS;
  }

  static bool IsIndexOperator(Kind tok) {
    return tok == kINDEX || tok == kASSIGN_INDEX;
  }

  static bool IsPseudoKeyword(Kind tok) {
    return (Attributes(tok) & kPseudoKeyword) != 0;
  }

  static bool IsKeyword(Kind tok) {
    return (Attributes(tok) & kKeyword) != 0;
  }

  static bool IsIdentifier(Kind tok) {
    return (tok == kIDENT) || IsPseudoKeyword(tok);
  }

  static const char* Name(Kind tok) {
    ASSERT(tok < kNumTokens);
    return name_[tok];
  }

  static const char* Str(Kind tok) {
    ASSERT(tok < kNumTokens);
    return tok_str_[tok];
  }

  static int Precedence(Kind tok) {
    ASSERT(tok < kNumTokens);
    return precedence_[tok];
  }

  static Attribute Attributes(Kind tok) {
    ASSERT(tok < kNumTokens);
    return attributes_[tok];
  }

  static bool CanBeOverloaded(Kind tok) {
    ASSERT(tok < kNumTokens);
    return IsRelationalOperator(tok) ||
           (tok == kEQ) ||
           (tok >= kADD && tok <= kMOD) ||  // Arithmetic operations.
           (tok >= kBIT_OR && tok <= kSHR) ||  // Bit operations.
           (tok == kINDEX) ||
           (tok == kASSIGN_INDEX);
  }

  static bool NeedsLiteralToken(Kind tok) {
    ASSERT(tok < kNumTokens);
    return ((tok == Token::kINTEGER) ||
            (tok == Token::kSTRING) ||
            (tok == Token::kINTERPOL_VAR) ||
            (tok == Token::kERROR) ||
            (tok == Token::kDOUBLE));
  }

  static bool IsBinaryOperator(Token::Kind token);
  static bool IsUnaryOperator(Token::Kind token);

  static bool IsBinaryArithmeticOperator(Token::Kind token);
  static bool IsUnaryArithmeticOperator(Token::Kind token);

  // For a comparison operation return an operation for the negated comparison:
  // !(a (op) b) === a (op') b
  static Token::Kind NegateComparison(Token::Kind op) {
    switch (op) {
      case Token::kEQ: return Token::kNE;
      case Token::kNE: return Token::kEQ;
      case Token::kLT: return Token::kGTE;
      case Token::kGT: return Token::kLTE;
      case Token::kLTE: return Token::kGT;
      case Token::kGTE: return Token::kLT;
      case Token::kEQ_STRICT: return Token::kNE_STRICT;
      case Token::kNE_STRICT: return Token::kEQ_STRICT;
      case Token::kIS:    return Token::kISNOT;
      case Token::kISNOT: return Token::kIS;
      default:
        UNREACHABLE();
        return Token::kILLEGAL;
    }
  }

 private:
  static const char* name_[];
  static const char* tok_str_[];
  static const uint8_t precedence_[];
  static const Attribute attributes_[];
};

}  // namespace dart

#endif  // VM_TOKEN_H_
