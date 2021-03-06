// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "vm/globals.h"
#if defined(TARGET_ARCH_X64)

#include "vm/isolate.h"
#include "vm/dart_entry.h"
#include "vm/native_entry.h"
#include "vm/native_entry_test.h"
#include "vm/object.h"
#include "vm/runtime_entry.h"
#include "vm/stub_code.h"
#include "vm/symbols.h"
#include "vm/unit_test.h"

#define __ assembler->

namespace dart {

static Function* CreateFunction(const char* name) {
  const String& class_name = String::Handle(Symbols::New("ownerClass"));
  const Script& script = Script::Handle();
  const Class& owner_class =
      Class::Handle(Class::New(class_name, script, Token::kNoSourcePos));
  const Library& lib = Library::Handle(Library::New(class_name));
  owner_class.set_library(lib);
  const String& function_name = String::ZoneHandle(Symbols::New(name));
  Function& function = Function::ZoneHandle(
      Function::New(function_name, RawFunction::kRegularFunction,
                    true, false, false, false, false, owner_class, 0));
  return &function;
}


// Test calls to stub code which calls into the runtime.
static void GenerateCallToCallRuntimeStub(Assembler* assembler,
                                          int length) {
  const int argc = 2;
  const Smi& smi_length = Smi::ZoneHandle(Smi::New(length));
  __ EnterStubFrame();
  __ PushObject(Object::null_object());  // Push Null obj for return value.
  __ PushObject(smi_length);             // Push argument 1: length.
  __ PushObject(Object::null_object());  // Push argument 2: type arguments.
  ASSERT(kAllocateArrayRuntimeEntry.argument_count() == argc);
  __ CallRuntime(kAllocateArrayRuntimeEntry, argc);
  __ AddImmediate(RSP, Immediate(argc * kWordSize));
  __ popq(RAX);  // Pop return value from return slot.
  __ LeaveStubFrame();
  __ ret();
}


TEST_CASE(CallRuntimeStubCode) {
  extern const Function& RegisterFakeFunction(const char* name,
                                              const Code& code);
  const int length = 10;
  const char* kName = "Test_CallRuntimeStubCode";
  Assembler _assembler_;
  GenerateCallToCallRuntimeStub(&_assembler_, length);
  const Code& code = Code::Handle(Code::FinalizeCode(
      *CreateFunction("Test_CallRuntimeStubCode"), &_assembler_));
  const Function& function = RegisterFakeFunction(kName, code);
  Array& result = Array::Handle();
  result ^= DartEntry::InvokeFunction(function, Object::empty_array());
  EXPECT_EQ(length, result.Length());
}


// Test calls to stub code which calls into a leaf runtime entry.
static void GenerateCallToCallLeafRuntimeStub(Assembler* assembler,
                                              const char* value1,
                                              const char* value2) {
  const Bigint& bigint1 =
      Bigint::ZoneHandle(Bigint::NewFromCString(value1, Heap::kOld));
  const Bigint& bigint2 =
      Bigint::ZoneHandle(Bigint::NewFromCString(value2, Heap::kOld));
  __ EnterStubFrame();
  __ ReserveAlignedFrameSpace(0);
  __ LoadObject(CallingConventions::kArg1Reg, bigint1);
  __ LoadObject(CallingConventions::kArg2Reg, bigint2);
  __ CallRuntime(kBigintCompareRuntimeEntry, 2);
  __ SmiTag(RAX);
  __ LeaveStubFrame();
  __ ret();  // Return value is in RAX.
}


TEST_CASE(CallLeafRuntimeStubCode) {
  extern const Function& RegisterFakeFunction(const char* name,
                                              const Code& code);
  const char* value1 = "0xAAABBCCDDAABBCCDD";
  const char* value2 = "0xAABBCCDDAABBCCDD";
  const char* kName = "Test_CallLeafRuntimeStubCode";
  Assembler _assembler_;
  GenerateCallToCallLeafRuntimeStub(&_assembler_, value1, value2);
  const Code& code = Code::Handle(Code::FinalizeCode(
      *CreateFunction("Test_CallLeafRuntimeStubCode"), &_assembler_));
  const Function& function = RegisterFakeFunction(kName, code);
  Smi& result = Smi::Handle();
  result ^= DartEntry::InvokeFunction(function, Object::empty_array());
  EXPECT_EQ(1, result.Value());
}

}  // namespace dart

#endif  // defined TARGET_ARCH_X64
