# Microsoft Visual C++ Name Mangling (MSVC Demangling)

## Overview

Microsoft Visual C++ uses a proprietary name-mangling scheme to encode C++ symbol information (namespaces, types, calling conventions, access modifiers) into linker-visible symbol names. All mangled symbols begin with a `?` prefix.

This document describes the encoding rules as implemented in the LLVM demangler.

## Top-Level Structure

A mangled symbol has the general form:

```
?<symbol-name>@<scope-pieces>@@<encoding>
```

Special prefixes:
- `.` — RTTI type descriptor
- `??@` — MD5-mangled name (for symbols exceeding length limits)

## Qualified Names

Names are encoded **in reverse order** separated by `@`, terminated by `@@`.

For example, `A::B::C` is encoded as `C@B@A@@`.

Special scope pieces:
- `?A<identifier>@` — anonymous namespace
- `?<number>?` — locally scoped name with numeric discriminator

## Number Encoding

Numbers used throughout the scheme are encoded as:
- `0-9` — directly (value = digit, i.e. `1` encodes 0, `2` encodes 1, etc.)
- `A-P` followed by `@` — hex digit encoding (A=0, B=1, ..., P=15), multiple characters form the number MSB-first
(used for the number 0 or numbers > 10)
- `?<number>` — negative number

## Type Encoding

### Primitive Types

| Code | Type |
|------|------|
| `X` | `void` |
| `D` | `char` |
| `C` | `signed char` |
| `E` | `unsigned char` |
| `F` | `short` |
| `G` | `unsigned short` |
| `H` | `int` |
| `I` | `unsigned int` |
| `J` | `long` |
| `K` | `unsigned long` |
| `M` | `float` |
| `N` | `double` |
| `O` | `long double` |
| `_N` | `bool` |
| `_J` | `__int64` |
| `_K` | `unsigned __int64` |
| `_W` | `wchar_t` |
| `_Q` | `char8_t` |
| `_S` | `char16_t` |
| `_U` | `char32_t` |
| `_P` | `auto` |
| `_T` | `decltype(auto)` |
| `$$T` | `std::nullptr_t` |

### Tag Types (class/struct/union/enum)

| Prefix | Meaning |
|--------|---------|
| `T` | `union` |
| `U` | `struct` |
| `V` | `class` |
| `W4` | `enum` |

Format: prefix + fully-qualified-name (e.g. `VMyClass@@` for `class MyClass`).

### Pointer and Reference Types

| Code | Meaning |
|------|---------|
| `P` | Pointer (`*`) |
| `A` | Reference (`&`) |
| `$$Q` | Rvalue reference (`&&`) |

Extended pointer qualifiers (can be combined):
- `E` — 64-bit pointer (`__ptr64`)
- `I` — `__restrict`
- `F` — `__unaligned`

## Qualifiers (const/volatile)

### For Non-Member Context

| Code | Meaning |
|------|---------|
| `A` | unqualified |
| `B` | `const` |
| `C` | `volatile` |
| `D` | `const volatile` |

### For Member Context

| Code | Meaning |
|------|---------|
| `Q` | unqualified |
| `R` | `const` |
| `S` | `volatile` |
| `T` | `const volatile` |

## Function Encoding

### Access / Storage Class

The first character(s) after `@@` encode access level and modifiers:

| Code | Meaning |
|------|---------|
| `A` | private |
| `C` | private static |
| `E` | private virtual |
| `I` | protected |
| `K` | protected static |
| `M` | protected virtual |
| `Q` | public |
| `S` | public static |
| `U` | public virtual |
| `Y` | global (non-member) |

Additional codes exist for `far` variants (B, D, F, J, L, N, R, T, V, Z) and this-adjustment thunks (G, H, O, P, W, X).

### Variable Storage Class

| Code | Meaning |
|------|---------|
| `0` | private static member |
| `1` | protected static member |
| `2` | public static member |
| `3` | global variable |
| `4` | static local variable |

### Calling Conventions

| Code | Convention |
|------|------------|
| `A` | `__cdecl` |
| `C` | `__pascal` |
| `E` | `__thiscall` |
| `G` | `__stdcall` |
| `I` | `__fastcall` |
| `M` | `__clrcall` |
| `O` | `__eabi` |
| `Q` | `__vectorcall` |
| `S` | `__swift` |
| `W` | `__swiftasynccall` |

Some conventions have even/odd variants (A/B, C/D, E/F, G/H, I/J, M/N, O/P) used in different contexts.

### Function Parameters

Parameters are encoded sequentially after the calling convention and return type. The parameter list is terminated by:
- `@` — non-variadic function
- `Z` — variadic function (last parameter is `...`)

## Operators

### Basic Operators (?0-?Z)

| Code | Operator |
|------|----------|
| `?0` | Constructor |
| `?1` | Destructor |
| `?2` | `operator new` |
| `?3` | `operator delete` |
| `?4` | `operator=` |
| `?5` | `operator>>` |
| `?6` | `operator<<` |
| `?7` | `operator!` |
| `?8` | `operator==` |
| `?9` | `operator!=` |
| `?A` | `operator[]` |
| `?B` | Conversion operator |
| `?C` | `operator->` |
| `?D` | `operator*` (dereference) |
| `?E` | `operator++` |
| `?F` | `operator--` |
| `?G` | `operator-` (unary/binary) |
| `?H` | `operator+` |
| `?I` | `operator&` |
| `?J` | `operator->*` |
| `?K` | `operator/` |
| `?L` | `operator%` |
| `?M` | `operator<` |
| `?N` | `operator<=` |
| `?O` | `operator>` |
| `?P` | `operator>=` |
| `?Q` | `operator,` |
| `?R` | `operator()` |
| `?S` | `operator~` |
| `?T` | `operator^` |
| `?U` | `operator\|` |
| `?V` | `operator&&` |
| `?W` | `operator\|\|` |
| `?X` | `operator*=` |
| `?Y` | `operator+=` |
| `?Z` | `operator-=` |

### Extended Operators (?_0-?_V)

| Code | Operator |
|------|----------|
| `?_0` | `operator/=` |
| `?_1` | `operator%=` |
| `?_2` | `operator>>=` |
| `?_3` | `operator<<=` |
| `?_4` | `operator&=` |
| `?_5` | `operator\|=` |
| `?_6` | `operator^=` |
| `?_U` | `operator new[]` |
| `?_V` | `operator delete[]` |

### Modern C++ Operators (?__K-?__M)

| Code | Operator |
|------|----------|
| `?__K` | `operator"" _name` (literal operator) |
| `?__L` | `operator co_await` |
| `?__M` | `operator<=>` (spaceship) |

## Special Names

| Code | Meaning |
|------|---------|
| `?_7` | vftable (virtual function table) |
| `?_8` | vbtable (virtual base table) |
| `?_9` | vcall thunk |
| `?_B` | local static guard |
| `?_C` | string literal |
| `?_R0` | RTTI type descriptor |
| `?_R1` | RTTI base class descriptor |
| `?_R2` | RTTI base class array |
| `?_R3` | RTTI class hierarchy descriptor |
| `?_R4` | RTTI complete object locator |
| `?_S` | local vftable |
| `?__E` | dynamic initializer |
| `?__F` | dynamic atexit destructor |
| `?__J` | local static thread guard |

## Templates

Template instantiations are marked with `?$` followed by the template name, then template parameters.

Template parameter types:
- `$$Y` — template alias
- `$$B` — array template parameter
- `$$C` — type with qualifiers
- `$0` — integral non-type template parameter (followed by encoded number)
- `$1`, `$H`, `$I`, `$J` — pointer-to-member non-type parameter variants
- `$E?` — reference to symbol

Parameter pack separators: `$S`, `$$V`, `$$$V`, `$$Z`

## Back-References

To compress repeated names and types, MSVC uses a back-reference system:

- Up to 10 names and 10 parameter types can be memorized
- Back-references are encoded as a single digit `0-9`
- Names are memorized on first occurrence if they're "complex enough"
- Single-character primitive types are not memorized (they don't save space)
- The back-reference table is shared across the entire mangled symbol

## Arrays

Array types are encoded as: `Y<rank><dim1><dim2>...@@<element-type>`

Where dimensions are encoded as numbers.

## Member Pointers

Member function pointers are distinguished from regular function pointers:
- `6` after pointer prefix — non-member function pointer
- `8` after pointer prefix — member function pointer

Member pointers include the class name in the encoding.

## This-Adjustment Thunks

Virtual function thunks encode adjustment offsets:
- Static this-adjust: codes `G`/`H`/`O`/`P`/`W`/`X` in the function class, followed by a signed offset
- Virtual this-adjust: `$0-$5` variants encoding base offset, VBPtrOffset, VBOffsetOffset, and VtordispOffset

## Examples

### Simple Cases

| Mangled | Demangled |
|---------|-----------|
| `?foo@@YAHXZ` | `int __cdecl foo(void)` |
| `?bar@B@A@@QAEXH@Z` | `void __thiscall A::B::bar(int)` |

Breaking down `?foo@@YAHXZ`:
- `?` — mangled symbol prefix
- `foo` — name
- `@@` — qualified name terminator (global scope)
- `Y` — global function
- `A` — `__cdecl` calling convention
- `H` — return type `int`
- `X` — parameter `void`
- `Z` — end of function encoding

### Templates with Class Type Parameters

| Mangled | Demangled |
|---------|-----------|
| `??0?$Class@V?$Nested@VTypename@@@@@@QAE@XZ` | `__thiscall Class<class Nested<class Typename>>::Class<class Nested<class Typename>>(void)` |
| `??0?$L@V?$H@PAH@PR26029@@@PR26029@@QAE@XZ` | `__thiscall PR26029::L<class PR26029::H<int *>>::L<class PR26029::H<int *>>(void)` |
| `?template_template_fun@@YAXU?$Type@U?$Thing@USecond@@$00@@USecond@@@@@Z` | `void __cdecl template_template_fun(struct Type<struct Thing<struct Second, 1>, struct Second>)` |

### Templates with Function Pointer Parameters

| Mangled | Demangled |
|---------|-----------|
| `??0?$Class@$$A6AHXZ@@QAE@XZ` | `__thiscall Class<int __cdecl(void)>::Class<int __cdecl(void)>(void)` |
| `??$template_template_specialization@$$A6AXU?$Type@U?$Thing@USecond@@$00@@USecond@@@@@Z@@YAXXZ` | `void __cdecl template_template_specialization<void __cdecl(struct Type<struct Thing<struct Second, 1>, struct Second>)>(void)` |
| `??$FunctionPointerTemplate@$1?spam@@YAXXZ@@YAXXZ` | `void __cdecl FunctionPointerTemplate<&void __cdecl spam(void)>(void)` |

### Variadic Templates with Mixed Types

| Mangled | Demangled |
|---------|-----------|
| `??$variadic_fn_template@HHD$$BY01D@@YAXABH0ABDAAY01$$CBD@Z` | `void __cdecl variadic_fn_template<int, int, char, char[2]>(int const &, int const &, char const &, char const (&)[2])` |

### Templates with Array Parameters

| Mangled | Demangled |
|---------|-----------|
| `??0?$Class@$$BY04$$CBH@@QAE@XZ` | `__thiscall Class<int const[5]>::Class<int const[5]>(void)` |
| `??0?$Class@$$BY04QAH@@QAE@XZ` | `__thiscall Class<int *const[5]>::Class<int *const[5]>(void)` |

### Templates with Qualified Function Types

| Mangled | Demangled |
|---------|-----------|
| `?a@FTypeWithQuals@@3U?$S@$$A8@@BAHXZ@1@A` | `struct FTypeWithQuals::S<int __cdecl(void) const> FTypeWithQuals::a` |
| `?b@FTypeWithQuals@@3U?$S@$$A8@@CAHXZ@1@A` | `struct FTypeWithQuals::S<int __cdecl(void) volatile> FTypeWithQuals::b` |
| `?d@FTypeWithQuals@@3U?$S@$$A8@@GBAHXZ@1@A` | `struct FTypeWithQuals::S<int __cdecl(void) const &> FTypeWithQuals::d` |
| `?g@FTypeWithQuals@@3U?$S@$$A8@@HBAHXZ@1@A` | `struct FTypeWithQuals::S<int __cdecl(void) const &&> FTypeWithQuals::g` |

### Member Function Pointers as Template Arguments

| Mangled | Demangled |
|---------|-----------|
| `??$CallMethod@US@@$1?f@1@QAEXXZ@@YAXAAUS@@@Z` | `void __cdecl CallMethod<struct S, &public: void __thiscall S::f(void)>(struct S &)` |
| `??$ReadField@UU@@$J??_91@$BA@AEA@A@A@@@YAXAAUU@@@Z` | `void __cdecl ReadField<struct U, {[thunk]: __thiscall U::vcall'{0, {flat}}, 0, 0, 0}>(struct U &)` |

### STL-Style Templates

| Mangled | Demangled |
|---------|-----------|
| `??$emplace_back@ABH@?$vector@HV?$allocator@H@std@@@std@@QAE?A?<decltype-auto>@@ABH@Z` | `<decltype-auto> __thiscall std::vector<int, class std::allocator<int>>::emplace_back<int const &>(int const &)` |

### Member Pointers and Data Members

| Mangled | Demangled |
|---------|-----------|
| `?l@@3P8foo@@AEHH@ZQ1@` | `int (__thiscall foo::*l)(int)` |
| `?m@@3PRfoo@@DR1@` | `char const foo::*m` |
| `?Q@@3$$QEAP8Foo@@EAAXXZEA` | `void (__cdecl Foo::*&&Q)(void)` |
| `?memptrtofun7@@3R8B@@EAAP6AHXZXZEQ1@` | `int (__cdecl * (__cdecl B::*volatile memptrtofun7)(void))(void)` |
| `?memptrtofun9@@3P8B@@EAAQ6AHXZXZEQ1@` | `int (__cdecl *const (__cdecl B::*memptrtofun9)(void))(void)` |

### Complex Pointer and Array Types

| Mangled | Demangled |
|---------|-----------|
| `?FunArr@@3PAY0BE@P6AHHH@ZA` | `int (__cdecl *(*FunArr)[20])(int, int)` |
| `?color3@@3QAY02$$CBNA` | `double const (*const color3)[3]` |
| `?foo_qay144cbh@@YAX$$QAY144$$CBH@Z` | `void __cdecl foo_qay144cbh(int const (&&)[5][5])` |
| `?foo_aay144h@@YAXAAY144H@Z` | `void __cdecl foo_aay144h(int (&)[5][5])` |

### Operator Overloads in Templates

| Mangled | Demangled |
|---------|-----------|
| `??$?HH@S@@QEAAAEANH@Z` | `double & __cdecl S::operator+<int>(int)` |

### Conversion Operators with Templated Return Types

| Mangled | Demangled |
|---------|-----------|
| `??$?BH@CompoundTypeOps@@QAE?AU?$Bar@U?$Foo@H@@@@XZ` | `struct Bar<struct Foo<int>> __thiscall CompoundTypeOps::operator<int> struct Bar<struct Foo<int>>(void)` |

### Back-References in Action

| Mangled | Demangled |
|---------|-----------|
| `?mangle_yes_backref2@@YAXQBQ6AXXZ0@Z` | `void __cdecl mangle_yes_backref2(void (__cdecl *const *const)(void), void (__cdecl *const *const)(void))` |

Note: the `0` near the end is a back-reference to the first parameter type, avoiding re-encoding the entire `QBQ6AXXZ` sequence.

### Lambda and Local Types

| Mangled | Demangled |
|---------|-----------|
| `?lambda@?1??define_lambda@@YAHXZ@4V<lambda_1>@?0??1@YAHXZ@A` | `class 'int __cdecl define_lambda(void)'::'1'::<lambda_1> 'int __cdecl define_lambda(void)'::'2'::lambda` |

---

## Appendix: Sources

This document was compiled by Claude Code (Claude Opus 4.6, Anthropic) from its training data knowledge and from reading the LLVM demangler source code. The information is derived from the following sources:

- **LLVM MicrosoftDemangle.cpp** — `/Users/carlpeto/Code/swift-project/llvm-project/llvm/lib/Demangle/MicrosoftDemangle.cpp` — the main parser implementation (Apache 2.0 with LLVM Exceptions)
- **LLVM MicrosoftDemangle.h** — `/Users/carlpeto/Code/swift-project/llvm-project/llvm/include/llvm/Demangle/MicrosoftDemangle.h` — type declarations and parser state
- **LLVM MicrosoftDemangleNodes.h** — `/Users/carlpeto/Code/swift-project/llvm-project/llvm/include/llvm/Demangle/MicrosoftDemangleNodes.h` — AST node definitions and enumerations
- **LLVM MicrosoftDemangleNodes.cpp** — `/Users/carlpeto/Code/swift-project/llvm-project/llvm/lib/Demangle/MicrosoftDemangleNodes.cpp` — output formatting and node printing
- **LLVM demangler test suite** — `/Users/carlpeto/Code/swift-project/llvm-project/llvm/test/Demangle/ms-*.test` — mangled/demangled pairs used to verify the implementation (test files: ms-templates, ms-templates-memptrs, ms-mangle, ms-arg-qualifiers, ms-operators, ms-nested-scopes, ms-cxx11, ms-cxx14, ms-cxx20, ms-conversion-operators)
- **Reverse engineering by the LLVM community** — the MSVC mangling scheme has no official specification; the LLVM implementation is derived from community reverse-engineering efforts and testing against `undname.exe` (the Microsoft demangler)

**Note**: Microsoft has never published a formal specification of their C++ name mangling scheme. The encoding rules in this document are derived from the LLVM implementation which was built through reverse engineering and empirical testing. While highly accurate, edge cases may exist that are not fully documented here.
