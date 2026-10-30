---
title: "CodeGen - The Automation Engine"
chapter: "04"
created_at: "2025-09-22T15:30:19-04:00"
updated_at: "2026-10-29T12:00:00-04:00"
rn_version_origin:
  version: "0.81.4"
  tag: "v0.81.4"
  date: "2025-09-10"
  note: "Closest stable release at the chapter's original bootstrap date (2025-09-22)."
rn_version_current:
  version: "0.88.1+main"
  tag: "v0.88.1"
  commit: "9c7b0f5fafdaa986bd3dcff7d65c3d8d59861176"
  date: "2026-10-29"
  note: "Upstream RN main HEAD as of the refresh. Includes v0.88.1 stable; main is 795 commits past it."
tags: [react-native, new-architecture, codegen, turbo-modules, fabric, build-tools]
audit:
  status: "verified"
  baseline_branch: "audit/baseline-2026-05-23"
  verified_branch: "audit/verified-2026-05-23"
  report: "_verification/chapters/04-codegen/report.md"
taillog:
  - "2025-09-22T15:30:19-04:00 | Initial draft (RN 0.81.4 era)"
  - "2026-05-23T16:17:30-04:00 | Source-grounded audit pass against RN 0.86 (commit b32a6c9e9db). Corrected the TurboModule spec example (constants surfaced via getConstants, namespace import for TurboModuleRegistry), rewrote the generated-header example to match actual codegen output (three families: ObjC++ SpecJSI over a @protocol, JNI SpecJSI over a Java/Kotlin abstract class, and C++ CxxSpec template via CRTP), and added precise compile-time-safety mechanism. See _verification/chapters/04-codegen/report.md."
  - "2026-07-28T22:15:00-04:00 | Refresh against RN main ca750feefb1 (v0.87.0-rc.3 era). Documented TurboModules always-on, legacy interop compile-out gates, ArrayBuffer TurboModule support, Strict TypeScript API default, C++ Native Animated canary, and corrected remaining opt-out claims."
  - "2026-10-29T12:00:00-04:00 | Refresh against RN main 9c7b0f5fafd (v0.88.1 era). ArrayBuffer now supported by Java/JNI generators (0.88), Promise<ArrayBuffer> rejected, ObjC emits RCTArrayBuffer on main (NSMutableData on v0.88.1), codegen discovery fixes, refreshed line refs."
---

# Chapter 5: CodeGen - The Automation Engine

The New Architecture's goals of performance and type safety are enabled by JSI, Fabric, and TurboModules. The glue that binds them together and makes the system practical for developers is **CodeGen**. CodeGen is a build-time tool that automates the creation of the boilerplate interface code required to connect the JavaScript world to the native C++ core, as detailed in the official "Using Codegen" guide.[^2]

Its source code lives in the repository at `packages/react-native-codegen/`[^1], shipped as the `@react-native/codegen` npm package.[^3]

## The Motivation: Eliminating Manual Glue Code

In the legacy architecture, connecting JavaScript to native required developers to write and maintain two separate interfaces by hand. This manual process was tedious and notoriously error-prone:

-   A typo in a method name would lead to a runtime "red box" error.
-   A mismatched argument type could cause a crash or silent failure.
-   There was no single source of truth. The JavaScript and native code could easily drift out of sync.

CodeGen was created to solve this problem by making the JavaScript spec the **single source of truth** and automating the generation of the native-side interface code.

## The CodeGen Pipeline

The CodeGen process is a classic compiler pipeline that runs during the application's build phase. On iOS it is invoked from the CocoaPods install script (`packages/react-native/scripts/cocoapods/codegen.rb`). On Android the Gradle plugin runs the same generators via the shared executor in `packages/react-native/scripts/codegen/generate-artifacts-executor/`.[^4]

**1. Discovery and parsing.** A combiner scans the package's source tree for files that contain either `extends TurboModule` (a native module spec) or `codegenNativeComponent<...>` (a native component spec).[^5] Each matching file is handed to a Flow or TypeScript parser depending on its extension. The parsers live in `packages/react-native-codegen/src/parsers/flow/` and `packages/react-native-codegen/src/parsers/typescript/`.

**2. Schema generation.** The parser transforms each spec into a single language-agnostic JSON object that represents the complete API contract. This intermediate representation conforms to the `SchemaType` shape declared in `packages/react-native-codegen/src/CodegenSchema.d.ts` (TypeScript) and its Flow twin `CodegenSchema.js`.[^6] A separate `SchemaValidator.js` checks the combined schema for issues like duplicate module names across components and modules before generation runs.[^7]

**3. Code generation.** The schema is passed to the **generators** under `src/generators/`. The dispatcher in `RNCodegen.js` selects a generator set per target: `modulesIOS`, `modulesAndroid`, and `modulesCxx` for native modules; `componentsIOS` and `componentsAndroid` for Fabric components.[^8] Each generator is a JavaScript file that emits source strings via template literals. The output is written to disk in the project's `build/generated/ios/` (or its Android equivalent) and then compiled by the platform toolchain.

### A Concrete Example

Let's trace the process for a simple TurboModule.

**Step 1: The developer writes the spec in TypeScript.**

```typescript
// NativeMyModule.ts
import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';

export interface Spec extends TurboModule {
  readonly getConstants: () => {PI: number};
  readonly getSyncValue: (a: number, b: string) => string;
  readonly getValueWithPromise: () => Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('MyModule');
```

Two things worth noticing here. First, import from the public `'react-native'` entry — under the Strict TypeScript API (default since v0.87.0), deep `Libraries/TurboModule/...` imports have `"types": null` unless you opt into `react-native-legacy-deep-imports`.[^9] Second, **a TurboModule spec interface may only contain function-typed properties (and non-nullable event emitters).** Bare data fields like `readonly PI: number;` are rejected at parse time with `UnsupportedModulePropertyParserError` ("TS interfaces extending TurboModule must only contain 'FunctionTypeAnnotation's or non nullable 'EventEmitter's").[^10] Constants are surfaced through the `getConstants` method whose return type carries the constant shape, which is exactly the pattern the canonical samples follow.[^11]

**Step 2: CodeGen generates the C++ Spec Header.**

The output depends on which generator target produced it. There are three families, each with its own conventions:

*iOS (`modulesIOS`).* The generator writes a `<LibraryName>.h` header that declares an Objective-C protocol the developer implements, plus a C++ wrapper class that bridges that protocol to JSI:[^12]

```objc
// Generated by GenerateModuleObjCpp (excerpt)

@protocol NativeMyModuleSpec <RCTBridgeModule, RCTTurboModule>
- (facebook::react::ModuleConstants<JS::NativeMyModule::Constants>)getConstants;
- (NSString *)getSyncValue:(double)a b:(NSString *)b;
- (void)getValueWithPromise:(RCTPromiseResolveBlock)resolve
                     reject:(RCTPromiseRejectBlock)reject;
@end

namespace facebook::react {
  class JSI_EXPORT NativeMyModuleSpecJSI : public ObjCTurboModule {
   public:
    NativeMyModuleSpecJSI(const ObjCTurboModule::InitParams &params);
  };
} // namespace facebook::react
```

The `SpecJSI` class is intentionally small. Its constructor registers each method into the inherited `methodMap_` and hands a static `__hostFunction_*` thunk that calls `invokeObjCMethod(rt, kind, "name", @selector(...), args, count)` at runtime. There are **no pure virtual methods**; the Objective-C protocol is the contract the developer satisfies, and `invokeObjCMethod` uses the protocol selectors at call time.[^13]

*Android (`modulesAndroid`).* The Android generators emit a `JavaTurboModule`-based `SpecJSI` plus a Java/Kotlin abstract class (e.g., `NativeMyModuleSpec`) for the developer to subclass. The C++ side is again a thin shim that routes calls through JNI:

```cpp
// Generated by GenerateModuleJniH.js (excerpt)
class JSI_EXPORT NativeMyModuleSpecJSI : public JavaTurboModule {
 public:
  NativeMyModuleSpecJSI(const JavaTurboModule::InitParams &params);
};
```

*Pure C++ (`modulesCxx`).* When a TurboModule is implemented entirely in C++ (no platform code), the generator emits a CRTP-style class template that **the developer's class derives from**:[^14]

```cpp
// Generated by GenerateModuleH.js (excerpt)

template <typename T>
class JSI_EXPORT NativeMyModuleCxxSpec : public TurboModule {
 public:
  static constexpr std::string_view kModuleName = "MyModule";

 protected:
  NativeMyModuleCxxSpec(std::shared_ptr<CallInvoker> jsInvoker)
      : TurboModule(std::string{kModuleName}, jsInvoker) {
    methodMap_["getSyncValue"] = MethodMetadata{
        .argCount = 2, .invoker = __getSyncValue};
    methodMap_["getValueWithPromise"] = MethodMetadata{
        .argCount = 0, .invoker = __getValueWithPromise};
    methodMap_["getConstants"] = MethodMetadata{
        .argCount = 0, .invoker = __getConstants};
  }

 private:
  static jsi::Value __getSyncValue(
      jsi::Runtime &rt,
      TurboModule &tm,
      const jsi::Value *args,
      size_t count) {
    static_assert(
        bridging::getParameterCount(&T::getSyncValue) == 3,
        "Expected getSyncValue(...) to have 3 parameters");
    return bridging::callFromJs<jsi::String>(
        rt,
        &T::getSyncValue,
        static_cast<NativeMyModuleCxxSpec *>(&tm)->jsInvoker_,
        static_cast<T *>(&tm),
        args[0].asNumber(),
        args[1].asString(rt));
  }
  // ... __getValueWithPromise, __getConstants ...
};
```

Note three things. The class name ends in `CxxSpec`, not `SpecJSI`. It is a `template <typename T>` (the `T` is the developer's concrete subclass). Dispatch goes through static `__methodName` callbacks that forward to `T::methodName` via `bridging::callFromJs`, not through C++ virtual methods. Compile-time safety here comes from the `static_assert(bridging::getParameterCount(&T::method) == N, ...)` lines, which fail to substitute if the developer's class is missing a method or its arity is wrong.[^15]

**Step 3: The developer implements the generated interface.**

What "implementing the interface" means is platform-specific:

-   On iOS, the developer writes an Objective-C class that conforms to the `<NativeMyModuleSpec>` protocol. The Objective-C compiler emits `-Wprotocol` warnings for unimplemented methods, and Xcode flags wrong selector signatures.
-   On Android, the developer subclasses the generated Java/Kotlin abstract class `NativeMyModuleSpec`. Missing methods are a compile error.
-   For the pure C++ Cxx variant, the developer writes a class that derives from `NativeMyModuleCxxSpec<MyClass>` (CRTP) and provides ordinary member functions with matching names and signatures. A missing method, or a parameter count mismatch, fails the `static_assert` and the build stops at the generated header.

In every case the JS-to-native shape is fixed by the spec and re-validated at compile time on the native side. There is no path where the runtime gets to discover a name or argument mismatch and crash later.

### Platform matrix for newer types (v0.87)

Not every annotation lands on every generator. `ArrayBuffer` / `ArrayBufferTypeAnnotation` is a first-class schema type. The **C++** generator (`GenerateModuleH.js`) and **ObjC** generator (`GenerateModuleObjCpp`) emit it since v0.87. The **Java** and **JNI** generators emit it since v0.88 (`com.facebook.react.bridge.ArrayBuffer`, JNI signature `Lcom/facebook/react/bridge/ArrayBuffer;`). The C++ fixture ships a `getArrayBuffer` / `voidArrayBuffer` sample in the snapshot tests.[^15] One shared guard, `throwIfUnsupportedPromiseArrayBuffer`, rejects `Promise<ArrayBuffer>` on Java and ObjC. `ArrayBuffer` as an argument or as a synchronous return value works on every platform.[^16] On the ObjC side, the generated type is `NSMutableData *` on v0.87.0 and v0.88.1, and `RCTArrayBuffer *` on main after v0.88.1. The 0.88 changelog records a revert of the `RCTArrayBuffer` change on the 0.88 line. Discovery also got fixes after 0.87: the crawler skips `node_modules` and symlinks when it searches for components (`39751d864dd`), and it reads `react-native.config.cjs` so ESM projects are no longer skipped silently (`583c8f3afb2`). Separately, pure-C++ TurboModules no longer require `includesGeneratedCode: true` in `codegenConfig` for Android autolinking to pick them up.[^17]

## The Benefit: Compile-Time Safety

This automated process is the key to the New Architecture's type safety. By generating native interfaces from a single JavaScript source of truth, it makes the native implementation impossible to drift out of sync with the JavaScript API without a build failure. The exact mechanism is different on each target (protocol conformance on iOS, abstract subclass on Android, CRTP plus `static_assert` for Cxx), but the contract is the same: a class of fragile, runtime-dependent errors moves into easy-to-diagnose compile-time errors.

---

**Citations:**

[^1]: `packages/react-native-codegen/` (RN HEAD `9c7b0f5fafd`).
[^2]: "Using Codegen". React Native Documentation. [https://reactnative.dev/docs/the-new-architecture/using-codegen](https://reactnative.dev/docs/the-new-architecture/using-codegen).
[^3]: `packages/react-native-codegen/package.json` (`"name": "@react-native/codegen"`, current version `0.87.0-main`).
[^4]: `packages/react-native/scripts/cocoapods/codegen.rb:9-39` (the `run_codegen!` Ruby helper invoked by `use_react_native_codegen_discovery!`); `packages/react-native/scripts/codegen/generate-artifacts-executor/` (cross-platform driver).
[^5]: `packages/react-native-codegen/src/cli/combine/combine-js-to-schema.js:24-35` (`combineSchemas` filters files via `/extends TurboModule/` or `/export\s+default\s+\(?codegenNativeComponent</`).
[^6]: `packages/react-native-codegen/src/CodegenSchema.d.ts:12` (`interface SchemaType`); `packages/react-native-codegen/src/CodegenSchema.js` (Flow twin).
[^7]: `packages/react-native-codegen/src/SchemaValidator.js:17` (`function getErrors(schema: SchemaType)`).
[^8]: `packages/react-native-codegen/src/generators/RNCodegen.js:125-181` (the `LIBRARY_GENERATORS` map: `modulesIOS: [generateModuleObjCpp.generate]`, `modulesAndroid: [generateModuleJniCpp.generate, generateModuleJniH.generate, generateModuleJavaSpec.generate]`, `modulesCxx: [generateModuleH.generate]`).
[^9]: Prefer `import { TurboModuleRegistry } from 'react-native'` / `import type { TurboModule } from 'react-native'` under the Strict TypeScript API. The deep module still implements `get` / `getEnforcing` as named exports (`Libraries/TurboModule/TurboModuleRegistry.js:35,39`). The public type surface is `ReactNativeApi.d.ts`, which declares `namespace TurboModuleRegistry { export { get_2 as get, getEnforcing } }` (line 5406).
[^10]: `packages/react-native-codegen/src/parsers/parsers-commons.js:462` (calls `throwIfModuleTypeIsUnsupported`); `packages/react-native-codegen/src/parsers/error-utils.js:219` (the check); `packages/react-native-codegen/src/parsers/errors.js:129` (`UnsupportedModulePropertyParserError`, message at line 140: "interfaces extending TurboModule must only contain 'FunctionTypeAnnotation's or non nullable 'EventEmitter's").
[^11]: `packages/rn-tester/js/examples/TurboModule/NativeSampleTurboModule.js` (moved out of `src/private/specs_DEPRECATED/modules/` by `4ffc4a65231`; `readonly getConstants: () => { const1: boolean, const2: number, const3: string }`).
[^12]: `packages/react-native-codegen/src/generators/modules/GenerateModuleObjCpp/index.js:25` (`ModuleDeclarationTemplate`). Real snapshot output for a methods-bearing module: `packages/react-native-codegen/src/generators/modules/__tests__/__snapshots__/GenerateModuleHObjCpp-test.js.snap:800-832` (`@protocol NativeCameraRollManagerSpec` + `NativeCameraRollManagerSpecJSI : public ObjCTurboModule`).
[^13]: `packages/react-native-codegen/src/generators/modules/__tests__/__snapshots__/GenerateModuleMm-test.js.snap:130-181` (the `.mm` source registers each method with `methodMap_["name"] = MethodMetadata{argCount, __hostFunction_..._name}` and the static thunks call `invokeObjCMethod(rt, Kind, "name", @selector(...), args, count)`).
[^14]: `packages/react-native-codegen/src/generators/modules/GenerateModuleH.js:160` (`ModuleSpecClassDeclarationTemplate`). Real snapshot: `packages/react-native-codegen/src/generators/modules/__tests__/__snapshots__/GenerateModuleH-test.js.snap:43-105` (the `array_buffer_native_module` fixture).
[^15]: `packages/react-native-codegen/src/generators/modules/__tests__/__snapshots__/GenerateModuleH-test.js.snap:74-78` (`static_assert(bridging::getParameterCount(&T::getArrayBuffer) == 1, "Expected getArrayBuffer(...) to have 1 parameters");`).
[^16]: `packages/react-native-codegen/src/generators/modules/Utils.js:95` (`throwIfUnsupportedPromiseArrayBuffer`, rejects `Promise<ArrayBuffer>`). Java maps the type in `GenerateModuleJavaSpec.js:284,381`, JNI in `GenerateModuleJniCpp.js:313,399`. The Java class is `ReactAndroid/.../bridge/ArrayBuffer.kt` (CHANGELOG v0.88.0). ObjC emits `ArrayBufferKind` and `RCTArrayBuffer *` on main via `GenerateModuleObjCpp/serializeMethod.js:230,401` (`11f9a7f4491`). At `v0.88.1` those lines emit `NSMutableData *`. Schema type: `CodegenSchema.d.ts:49` `ArrayBufferTypeAnnotation`. The old text "ArrayBuffer is only supported for C++ TurboModules" is gone from the generators.
[^17]: CHANGELOG v0.87.0 Fixed: "Fix pure C++ turbo modules not working without `includesGeneratedCode: true`" (`c789880517`).
