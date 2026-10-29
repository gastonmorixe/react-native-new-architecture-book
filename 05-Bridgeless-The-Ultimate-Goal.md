---
title: "Bridgeless: the ultimate goal"
chapter: "05"
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
tags: [react-native, new-architecture, bridgeless, jsi, turbomodules, interop, react-host, react-instance]
audit:
  status: "verified"
  baseline_branch: "audit/baseline-2026-05-23"
  verified_branch: "audit/verified-2026-05-23"
  report: "_verification/chapters/05-bridgeless/report.md"
taillog:
  - "2025-09-22T15:30:19-04:00 | Initial draft (RN 0.81.4 era)"
  - "2026-05-23T16:13:55-0400 | Source-grounded audit pass against RN 0.86 (commit b32a6c9e9db). Fixed chapter number (was 'Chapter 6' on a file named 05-…), corrected the 0.74 blog citation URL, qualified the 'synchronous JSI' claim, added the v0.76 default-on context, named the actual runtime types (ReactInstance / ReactHost / RCTHost), pointed at the real interop classes (ObjCInteropTurboModule, JavaInteropTurboModule, RCTBridgeProxy), and fixed the mermaid diagram (the original `note left of NA:` is sequenceDiagram syntax and silently dropped its text in a flowchart). See _verification/chapters/05-bridgeless/report.md."
  - "2026-07-28T22:15:00-04:00 | Refresh against RN main ca750feefb1 (v0.87.0-rc.3 era). Documented TurboModules always-on, legacy interop compile-out gates, ArrayBuffer TurboModule support, Strict TypeScript API default, C++ Native Animated canary, and corrected remaining opt-out claims."
  - "2026-10-29T12:00:00-04:00 | Refresh against RN main 9c7b0f5fafd (v0.88.1 era). Fixed stale iOS claims: RCTRootViewFactoryConfiguration no longer has bridgelessEnabled (removed in 2a9eca81b8d), RCTTurboModuleEnabled() is deleted (01d55273bcf) not just always-YES, RCTInstance no longer calls setCurrentBridge and passes RCTBridgeProxy to RCTTurboModuleManager instead. Updated line refs, interop gates (RCT_REMOVE_LEGACY_*_INTEROP are opt-in via CocoaPods and SwiftPM since 0.88, default off), and 0.87/0.88 wording."
---

# Chapter 6: Bridgeless - The Ultimate Goal

The introduction of the JSI, Fabric, and TurboModules provides the foundational pieces to replace the legacy architecture. However, for a time, both the old and new systems could coexist in a single application to provide backward compatibility. The ultimate goal of the new architecture, however, was to completely remove the old one. This final state is known as **Bridgeless Mode**.

Bridgeless Mode was first made available as an opt-in with React Native 0.73 (December 2023), became the default for New Architecture-enabled apps in React Native 0.74 (April 22, 2024) [^1], and has been on for every new project since React Native 0.76 (October 2024), when the New Architecture itself became default-on [^2]. Opt-out of the New Architecture (and therefore of Bridgeless) was removed in React Native 0.82. At main HEAD (v0.88.1 era), the legacy non-bridgeless path on iOS is gone from the API: the `bridgelessEnabled` property and the `bridgelessEnabled:`/`turboModuleEnabled:` initializers were **deleted** from `RCTRootViewFactoryConfiguration`, and the old `RCTArchConfiguratorProtocol` (which exposed the `bridgelessEnabled`/`newArchEnabled`/`turboModuleEnabled`/`fabricEnabled` toggles) has been **removed from the public headers** rather than merely deprecated [^3]. The two remaining `newArchEnabled:` initializers are deprecated and ignore the flag. TurboModules are always enabled: the `useTurboModules` flag is gone (v0.87), and the iOS `RCTTurboModuleEnabled()` / `RCTEnableTurboModule()` functions are deleted from `RCTBridge.h` on main.

## What is Bridgeless Mode?

Bridgeless mode is not a new component or a separate piece of technology. It is the architectural state where the original, asynchronous message-based Bridge is **no longer initialized or used**. In this mode, communication between JavaScript and the native platform flows through the JavaScript Interface (JSI), not through the legacy JSON message queue.

Concretely, instead of an `RCTBridge` / `CatalystInstance` pair, the runtime is owned by a `ReactInstance` (C++) sitting under a platform `ReactHost` (`RCTHost` on iOS, `ReactHost` on Android) [^4]. On Android, `BridgelessReactContext` replaces `ReactApplicationContext`; its source comment is blunt about this: "This class is used instead of ReactApplicationContext when React Native is operating in bridgeless mode. The purpose of this class is to override some methods on ReactContext that use the CatalystInstance, which doesn't exist in bridgeless mode." [^5] On iOS, anywhere old code asks for the `[RCTBridge currentBridge]`, RN substitutes an `RCTBridgeProxy` (an `NSProxy` that forwards `RCTBridgeModule` selectors to the bridgeless module registry) so that legacy modules keep working without a real bridge underneath [^6].

In an earlier intermediate state (the New Architecture enabled but `bridgelessEnabled = NO`, which was possible in 0.73 and early 0.74 betas), the Bridge could still be initialized alongside Fabric and TurboModules to support unmigrated native modules. In Bridgeless mode that path is gone: no JSON message queue, no `MessageQueue.js` global serializer, no batched bridge.

## Visual: bridgeless module routing

```mermaid
flowchart TB
  subgraph NA["New Architecture (Bridgeless)"]
    JSI[JSI Runtime]
    TM[TurboModules]
    Interop["Interop layer<br/>ObjCInteropTurboModule (iOS)<br/>JavaInteropTurboModule (Android)"]
    Legacy["Legacy module<br/>(RCTBridgeModule on iOS,<br/>NativeModule on Android)"]
    JSI --> TM
    JSI --> Interop --> Legacy
  end
```

A modern TurboModule is reached through a CodeGen'd C++ binding installed on the JSI runtime. A legacy module is reached through one of two interop classes: `ObjCInteropTurboModule` on iOS [^7] or `JavaInteropTurboModule` on Android [^8]. Both subclass the platform's regular TurboModule base, expose the module's `RCT_EXPORT_METHOD` / `@ReactMethod` selectors as JSI properties via runtime introspection, and use a per-module method queue rather than the old global bridge queue.

## The Benefits of a Bridgeless World

Running without the Bridge unlocks the full potential of the New Architecture, leading to several key benefits:

1.  **Improved Performance:** This is the most significant advantage. By removing the need to initialize the Bridge and its modules at startup, apps launch faster. By eliminating the JSON serialization and the single batched message queue, communication latency is reduced. In code: `BridgelessNativeMethodCallInvoker` posts a raw `std::function<void()>` to a `MessageQueueThread` instead of marshalling `folly::dynamic` -> JSON -> bridge queue [^9].

2.  **Simplified Architecture and Threading:** Without the Bridge, the mental model for developers becomes simpler. There is no longer a JSON-serialized asynchronous boundary to reason about. The threading model is still multi-threaded (JS thread, UI thread, background module queues), but coordination is done through the `RuntimeScheduler` and the `CallInvoker` abstraction, not through a global batched-bridge dispatcher [^10].

3.  **Unlocking Modern React Features:** Concurrent rendering and Suspense need synchronous reads from the renderer (for example, `measure`, `measureInWindow`, and the layout effect commit path). The legacy Bridge could not serve those without blocking the JS thread on a round-trip. With Fabric on a JSI-driven runtime, the renderer makes those reads inline through C++ shared state, which is what React 18's `concurrentRoot: true` requires on the `render()` call [^11].

A note on "synchronous." JSI itself is synchronous: `jsi::Runtime::call`, `jsi::Object::getProperty`, and friends are direct C++ calls that run on whatever thread invokes them [^12]. But a TurboModule method can still be async by design (returning a `Promise`, or annotated `async` on Android). In that case the call still leaves the JS thread via `NativeMethodCallInvoker::invokeAsync`, which posts to a `MessageQueueThread`. So "Bridgeless is fully synchronous" is too strong. The accurate framing is: JSON serialization and the single global message queue are gone, and every call now enters native code through a JSI binding, but cross-thread dispatch is still real and still scheduled.

## The Interoperability Layer

The React Native team understood that a hard cutover to the new architecture was not feasible for the vast ecosystem of existing apps and third-party libraries. To facilitate a gradual migration, an interoperability layer was created.

This layer allows legacy, Bridge-based native modules to continue functioning in a Bridgeless world. When JavaScript calls a method on a legacy module, the call enters native code through a JSI TurboModule binding, but the TurboModule on the other side is one of the interop wrappers (`ObjCInteropTurboModule` on iOS, `JavaInteropTurboModule` on Android). The wrapper discovers the legacy module's exported methods via runtime introspection of its `RCT_EXPORT_METHOD` / `@ReactMethod` declarations, converts arguments via `RCTConvert` (or its Java equivalent), and invokes the legacy method through `NSInvocation` / `jmethodID`. The legacy module's own `dispatch_queue_t methodQueue` (iOS) is wrapped in a `LegacyModuleNativeMethodCallInvoker` so the call still lands on the queue the module expected [^13].

While this allows for backward compatibility, it does not provide the performance benefits of true TurboModules. The interop path pays runtime introspection cost on first use, ObjC dynamic dispatch / JNI call overhead per invocation, and `RCTConvert`-style argument coercion that CodeGen'd modules skip.

**Status as of v0.88:** the interop layer itself is now on a deletion track. Shared C++ and platform legacy view-manager interop is compile-gated behind `RCT_REMOVE_LEGACY_COMPONENT_INTEROP`, and legacy TurboModule interop behind `RCT_REMOVE_LEGACY_MODULE_INTEROP` [^14]. Builds that define those macros no longer ship the shims. Since 0.88, CocoaPods (`ENV['RCT_REMOVE_LEGACY_MODULE_INTEROP'] = '1'`) and SwiftPM can opt in. Both default to off, and the CocoaPods helper says they "will default to 1 in a future React Native release". The long-term goal is unchanged: migrate the ecosystem to first-class TurboModule and Fabric APIs before those gates become unconditional.

In conclusion, Bridgeless mode represents the fulfillment of the New Architecture's promise: a faster, more efficient, and more capable React Native. It marks a definitive shift away from the original design and sets a new foundation for the future of the framework.

---

[^1]: "React Native 0.74 - Yoga 3.0, Bridgeless New Architecture, and more." React Native Blog, April 22, 2024. <https://reactnative.dev/blog/2024/04/22/release-0.74>. The 0.74 changelog lists "Make bridgeless the default when the New Arch is enabled" twice in `## 0.74.0` (once Android, once iOS) at `CHANGELOG-0.7x.md:2076` (commit `fe337f25be`) and `CHANGELOG-0.7x.md:2114` (commit `c91af773fa`).

[^2]: "React Native 0.76 - New Architecture by default." React Native Blog, October 23, 2024. <https://reactnative.dev/blog/2024/10/23/release-0.76-new-architecture>.

[^3]: `packages/react-native/Libraries/AppDelegate/RCTRootViewFactory.h:59-68` (only `initWithBundleURLBlock:` / `initWithBundleURL:` plus two `newArchEnabled:` variants marked `__deprecated_msg("The flag is ignored; ...")`). `bridgelessEnabled` was removed from `RCTRootViewFactoryConfiguration` in `2a9eca81b8d`, and the Fabric/TurboModule toggles in `562fe3433af`. `RCTArchConfiguratorProtocol.h` is no longer shipped as a public header (removed in commits such as `2148f15db5` / `ad9936faf6`, and `scripts/ios-prebuild/__docs__/headers-rules.md:217` calls it "since-removed"); leftover `#pragma mark - RCTArchConfiguratorProtocol` comments in `RCTDefaultReactNativeFactoryDelegate.mm` are historical markers, not a live toggle surface.

[^4]: iOS: `packages/react-native/ReactCommon/react/runtime/platform/ios/ReactCommon/RCTHost.h:75-96` (`RCTHostJSEngineProvider` typedef at line 75, initializers takes a `RCTHostJSEngineProvider`, no `RCTBridge` anywhere). C++ runtime: `packages/react-native/ReactCommon/react/runtime/ReactInstance.h:27` (`class ReactInstance final : private jsinspector_modern::InstanceTargetDelegate`). Android: `packages/react-native/ReactAndroid/src/main/java/com/facebook/react/ReactHost.kt:23-27` ("A ReactHost is an object that manages a single `com.facebook.react.runtime.ReactInstance`. A ReactHost can be constructed without initializing the ReactInstance, and it will continue to exist after the instance is destroyed.").

[^5]: `packages/react-native/ReactAndroid/src/main/java/com/facebook/react/runtime/BridgelessReactContext.kt:41-45`. The companion `BridgelessCatalystInstance` (same package) is annotated `@LegacyArchitecture(logLevel = LegacyArchitectureLogLevel.ERROR)` because every method on it throws `UnsupportedOperationException`. It exists only to keep old code that types against `CatalystInstance` compilable; using it at runtime is an error.

[^6]: `packages/react-native/React/Base/RCTBridgeProxy.h:20` (`@interface RCTBridgeProxy : NSProxy`). `packages/react-native/ReactCommon/react/runtime/platform/ios/ReactCommon/RCTInstance.mm:308-329` instantiates the proxy in the bridgeless setup path, and line 332 hands it to `RCTTurboModuleManager` (`initWithBridgeProxy:`) so legacy modules that read `self.bridge` get the proxy. Line 390 also inserts it in the `contextContainer`. (Older text said `RCTInstance` calls `[RCTBridge setCurrentBridge:]`. That call is no longer in this file on main.)

[^7]: `packages/react-native/ReactCommon/react/nativemodule/core/platform/ios/ReactCommon/RCTInteropTurboModule.h:24` (`class JSI_EXPORT ObjCInteropTurboModule : public ObjCTurboModule`). Method introspection: `RCTInteropTurboModule.mm:51-73` (`getMethodInfos` walks the class hierarchy looking for `__rct_export__`-prefixed selectors emitted by the `RCT_EXPORT_METHOD` macro).

[^8]: `packages/react-native/ReactCommon/react/nativemodule/core/platform/android/ReactCommon/JavaInteropTurboModule.h:23` (`class JSI_EXPORT JavaInteropTurboModule : public JavaTurboModule`).

[^9]: `packages/react-native/ReactCommon/react/runtime/BridgelessNativeMethodCallInvoker.cpp:16-25`. `invokeAsync` calls `messageQueueThread_->runOnQueue(std::move(func))`; `invokeSync` calls `runOnQueueSync`. No JSON, no `folly::dynamic` marshalling, no batched message buffer.

[^10]: `packages/react-native/ReactCommon/react/runtime/platform/ios/ReactCommon/RCTInstance.mm:306` (`auto jsCallInvoker = _reactInstance->createJSCallInvoker();`). The same `jsCallInvoker` is then passed to `RCTTurboModuleManager`, so TurboModules schedule JS work through the `RuntimeScheduler` rather than the bridge. (`createJSCallInvoker()` replaced the older explicit `RuntimeSchedulerCallInvoker` construction.)

[^11]: `packages/react-native/Libraries/Renderer/shims/ReactNativeTypes.js:158-164` defines `render(element, containerTag, callback, concurrentRoot, options)` on the Fabric host config. Setting `concurrentRoot: true` is what enables React's concurrent features (the repo now depends on React ^19.3.0) on a React Native root.

[^12]: `packages/react-native/ReactCommon/jsi/jsi/jsi.h:705` declares `class JSI_EXPORT Runtime : public IRuntime` with synchronous `Value getProperty(...)`, `bool hasProperty(...)`, `void setPropertyValue(...)`, etc. JSI calls execute inline on the caller's thread; they do not queue work.

[^13]: `packages/react-native/ReactCommon/react/nativemodule/core/platform/ios/ReactCommon/RCTTurboModuleManager.mm:135` defines `class LegacyModuleNativeMethodCallInvoker : public ModuleNativeMethodCallInvoker`. Lines 385-405 build it from the legacy module's `dispatch_queue_t methodQueue` and wrap the module in `ObjCInteropTurboModule`. The legacy method is invoked via `NSInvocation` against the original `RCT_EXPORT_METHOD` selectors.

[^14]: CHANGELOG v0.87.0: "Gate shared C++ and Android Java/Kotlin legacy view manager interop behind `RCT_REMOVE_LEGACY_COMPONENT_INTEROP`" (`9885fe95ef`); "Gate legacy TurboModule interop behind `RCT_REMOVE_LEGACY_MODULE_INTEROP`" (`3278f309e2`). Matching `#ifndef` guards appear in `packages/react-native/React/Base/RCTBridge.h:46-56`, `RCTInteropTurboModule.h:12`, `JavaInteropTurboModule.h:12`, `RCTTurboModuleManager.mm:163,237`, and `LegacyViewManagerInteropShadowNode.h:12`. v0.88.0 CHANGELOG (line 81): "Allow consumers to opt into `RCT_REMOVE_LEGACY_MODULE_INTEROP` and `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` from CocoaPods and SwiftPM. Both default to off and will become the default in a future release" (`b933d18177`). Default env wiring: `scripts/react_native_pods.rb:123-124`.
