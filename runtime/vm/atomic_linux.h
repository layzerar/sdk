// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef VM_ATOMIC_LINUX_H_
#define VM_ATOMIC_LINUX_H_

#if !defined VM_ATOMIC_H_
#error Do not include atomic_linux.h directly. Use atomic.h instead.
#endif

#if !defined(TARGET_OS_LINUX)
#error This file should only be included on Linux builds.
#endif

namespace dart {


inline uintptr_t AtomicOperations::FetchAndIncrement(uintptr_t* p) {
  return __sync_fetch_and_add(p, 1);
}


inline uintptr_t AtomicOperations::FetchAndIncrementBy(intptr_t* p,
                                                       intptr_t value) {
  return __sync_fetch_and_add(p, value);
}


inline uintptr_t AtomicOperations::FetchAndDecrement(uintptr_t* p) {
  return __sync_fetch_and_sub(p, 1);
}


inline uintptr_t AtomicOperations::FetchAndDecrementBy(intptr_t* p,
                                                       intptr_t value) {
  return __sync_fetch_and_sub(p, value);
}


#if !defined(USING_SIMULATOR)
inline uword AtomicOperations::CompareAndSwapWord(uword* ptr,
                                                  uword old_value,
                                                  uword new_value) {
  return __sync_val_compare_and_swap(ptr, old_value, new_value);
}


inline uint32_t AtomicOperations::CompareAndSwapUint32(uint32_t* ptr,
                                                       uint32_t old_value,
                                                       uint32_t new_value) {
  return __sync_val_compare_and_swap(ptr, old_value, new_value);
}
#endif  // !defined(USING_SIMULATOR)

}  // namespace dart

#endif  // VM_ATOMIC_LINUX_H_
