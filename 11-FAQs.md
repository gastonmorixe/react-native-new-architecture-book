---
title: "Frequently Asked Questions (FAQs)"
chapter: "11"
created_at: "2025-09-22T15:30:19-04:00"
updated_at: "2026-07-28T22:15:00-04:00"
rn_version_origin:
  version: "0.81.4"
  tag: "v0.81.4"
  date: "2025-09-10"
  note: "Closest stable release at the chapter's original bootstrap date (2025-09-22)."
rn_version_current:
  version: "0.87.0-rc.3+main"
  tag: "v0.87.0-rc.3"
  commit: "ca750feefb1f6f6cc7ac151825c76db6fc9dc66e"
  date: "2026-07-28"
  note: "Upstream RN main HEAD as of the refresh. Includes v0.86.2 stable and v0.87.0-rc.3; past rc.3 by a handful of main commits."
tags: [react-native, new-architecture, faq, turbomodules, fabric, bridgeless, jsi, interop, codegen]
audit:
  status: "verified"
  baseline_branch: "audit/baseline-2026-05-23"
  verified_branch: "audit/verified-2026-05-23"
  report: "_verification/chapters/11-faqs/report.md"
taillog:
  - "2025-09-22T15:30:19-04:00 | Initial draft (RN 0.81.4 era)"
  - "2026-05-23T16:17:31-0400 | Source-grounded audit pass against RN 0.86 (commit b32a6c9e9db). Fixed: footnote [^1] URL (/docs/next/architecture/landing-page 404 → /docs/next/the-new-architecture/landing-page); footnote [^5] URL (/docs/next/the-new-architecture/renderer 404 → /architecture/fabric-renderer); Q6 corrected (iOS modules are NOT registered in the Podfile, they're registered via codegenConfig.ios.modulesProvider in package.json on the New Arch path, with the Podfile only triggering pod install/Codegen); Q6 clarified that getEnforcing throws via invariant, not returns undefined; Q3 added a note that the TurboModule interop layer is ON by default in Bridgeless; Q1 added v0.86 status (RCTIsNewArchEnabled now hardcoded to YES in C++ utils, legacy opt-out still works via gradle.properties / Podfile env var). See _verification/chapters/11-faqs/report.md."
  - "2026-07-28T22:15:00-04:00 | Refresh against RN main ca750feefb1 (v0.87.0-rc.3 era). Documented TurboModules always-on, legacy interop compile-out gates, ArrayBuffer TurboModule support, Strict TypeScript API default, C++ Native Animated canary, and corrected remaining opt-out claims."
---

# Chapter 12: Frequently Asked Questions (FAQs)

This chapter addresses common high-level questions about the React Native New Architecture.

**1. Do I have to migrate to the New Architecture?**

Yes, if you want to stay on a supported React Native release. As of React Native 0.76, the New Architecture is the default for new projects.[^1] As of React Native 0.82, **opt-out was removed**: the only way to keep the legacy Bridge is to stay on a `0.81.x` (or earlier) tag. All future core development and Concurrent React features assume the New Architecture.

**Status as of v0.87 (`main`, commit `ca750feefb1`):** the New Architecture is hard-wired on. On iOS, `RCTIsNewArchEnabled()` unconditionally returns `YES` and the matching setter is a documented no-op.[^6] The Cocoapods helper `NewArchitectureHelper.new_arch_enabled` also returns `true` outright.[^7] Setting `newArchEnabled=false` in `android/gradle.properties` or `ENV['RCT_NEW_ARCH_ENABLED'] = '0'` in your iOS `Podfile` is force-overridden by the build tooling (error / warning, then enabled anyway). TurboModules are likewise always enabled: `RCTTurboModuleEnabled()` always returns `YES` and both it and `RCTEnableTurboModule()` are deprecated.[^17] Legacy Bridge symbols and the legacy module / view-manager interop layers are increasingly compile-gated behind `RCT_REMOVE_LEGACY_ARCH`, `RCT_REMOVE_LEGACY_MODULE_INTEROP`, and `RCT_REMOVE_LEGACY_COMPONENT_INTEROP`.[^8]

**2. Is the Bridge completely gone in the New Architecture?**

In **Bridgeless Mode** (the default for new architecture apps since RN 0.74), the original message-queue Bridge is no longer initialized or used.[^2] However, an **interoperability layer** still exists to support legacy native modules. So, while the old performance-bottleneck Bridge is gone, the system can still communicate with old modules.

Concretely, the New Arch detects Bridgeless via the JS global `RN$Bridgeless`. When it's set, `TurboModuleBinding::install` mounts a `BridgelessNativeModuleProxy` (a JSI `HostObject`) as `global.nativeModuleProxy`, and any access to that proxy resolves first through the TurboModule provider, then through an optional legacy module provider.[^9]

**3. Can I still use my old native modules and components?**

Yes, for the most part. The interoperability layer allows legacy `RCTBridgeModule`s and `ViewManager`s to function. However, they will not see the performance benefits of the new architecture. For full compatibility and performance, they should be migrated to TurboModules and Fabric Components.

The TurboModule interop is **on by default in Bridgeless** when the interop code is compiled in (OSS apps still ship it unless they define the removal macros): `RCTRootViewFactory.initializeReactHostWithLaunchOptions:` calls `RCTEnableTurboModuleInterop(YES)` before creating the React host on iOS,[^10] and the Android New-Arch defaults class sets `useTurboModuleInterop()` to `true`.[^11] Legacy `RCT_EXPORT_MODULE` modules are wrapped by `ObjCInteropTurboModule` (which dispatches through `NSInvocation`),[^12] and legacy `ViewManager`s are bridged into Fabric through the `LegacyViewManagerInterop*` shadow node and component descriptor.[^13] On the v0.87 line those interop entry points can be compiled out behind `RCT_REMOVE_LEGACY_MODULE_INTEROP` / `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` — opt-in macros, not the default OSS build. The extra indirection is what costs you performance versus a first-class TurboModule or Fabric component — and the compile-out gates are the signal that the shim path is temporary.

**4. Do I need to learn C++ to use the New Architecture?**

Not necessarily to *use* it, but it is highly beneficial if you are *writing* native modules. You can write TurboModules and Fabric Components using only Objective-C or Java/Kotlin, as CodeGen handles the C++ interface generation. However, understanding the C++ layer (especially JSI concepts like `HostObject`) is crucial for debugging and for unlocking advanced performance patterns, such as writing a single, cross-platform module in C++. The canonical example of the C++ path lives in the repo at `packages/rn-tester/NativeCxxModuleExample/`, with `NativeCxxModuleExample.cpp` shared between iOS and Android.[^14]

**5. What is the difference between a TurboModule and a Fabric Component?**

-   **TurboModules** are for non-UI native functionality. They replace the old `NativeModules`. Examples include accessing the device's calendar, camera, or file system.
-   **Fabric Components** are for UI. They replace the old `ViewManager`s. They are native views that are rendered on the screen, like a map view or a custom video player.

**6. Why is my new TurboModule `undefined` in JavaScript?**

This is a common issue during migration. To be precise about the failure mode: `TurboModuleRegistry.getEnforcing('Foo')` does not return `undefined`. It throws via `invariant` with the message `TurboModuleRegistry.getEnforcing(...): 'Foo' could not be found. Verify that a module by this name is registered in the native binary.`[^15] The non-throwing sibling `TurboModuleRegistry.get('Foo')` returns `null` (not `undefined`) when the lookup misses both the TurboModule proxy and the legacy `NativeModules[name]` fallback. The most frequent causes are:

-   **Name Mismatch:** The name used in `TurboModuleRegistry.getEnforcing('MyModule')` in JavaScript does not exactly match the name registered in the native code (e.g., in the `BaseReactPackage` on Android).[^3]
-   **CodeGen Not Run:** You have created or changed the JS `Spec` file but have not rebuilt the app. You must re-run `pod install` or rebuild your Gradle project to trigger CodeGen and link the new module.[^4]
-   **Module Not Registered:** On Android, your module needs to be returned from a `BaseReactPackage.getModule(...)` and listed in `getReactModuleInfoProvider().getReactModuleInfos()`, with that package added to `MainApplication.getPackages()`.[^3] On iOS, the New Arch path registers modules through `codegenConfig.ios.modulesProvider` in your library's `package.json` (not in the `Podfile`). `pod install` is what *runs* CodeGen against that config; the Podfile itself is not the registration site.[^3]

**7. Is the New Architecture always faster than the old one?**

For most real-world applications, yes. The benefits in app startup (from lazy loading), UI responsiveness (from Fabric), and native call speed (from JSI) are significant.[^1][^5] The lazy loading isn't marketing: `TurboModuleBinding::getModule` only calls the module provider on first request, and the JS-side `jsRepresentation` populates each method via `TurboModule::get` the first time JS touches it.[^16]

However, in some very simple, static rendering scenarios, the overhead of the new architecture's more complex machinery can make it appear marginally slower than the legacy system. The team itself acknowledges this when documenting the migration: "enabling the New Architecture in your app or library may not immediately improve the performance or user experience."[^1] The true benefits shine in complex applications with many native interactions and dynamic UIs.

**8. What broke for JS/tooling on the 0.87 line?**

A few non-architecture removals commonly trip upgrades:

-   **Strict TypeScript API is the default.** Prefer imports from `'react-native'`. Deep `Libraries/...` and `src/private/...` paths are untyped unless you set Metro `customConditions: ["react-native-legacy-deep-imports"]`.[^18]
-   **`InteractionManager` is gone.** Use `requestIdleCallback`.[^19]
-   **`'react-native/Libraries/Core/InitializeCore'` is deprecated.** Use `'react-native/setup-env'`.
-   **Jest:** use `preset: '@react-native/jest-preset'` (the old `react-native/jest-preset` subpath is removed).

See Chapter 7's "0.87 JS / tooling breakages" table for the full checklist.

---

**Citations:**

[^1]: "About the New Architecture". React Native Documentation. [https://reactnative.dev/architecture/landing-page](https://reactnative.dev/architecture/landing-page). (The `/docs/next/the-new-architecture/landing-page` URL still works via an internal `vercel.json` redirect, but the canonical URL is this one.)
[^2]: "React Native 0.74 - Yoga 3.0, Bridgeless New Architecture, and more". React Native Blog. [https://reactnative.dev/blog/2024/04/22/release-0.74](https://reactnative.dev/blog/2024/04/22/release-0.74). The matching CHANGELOG entries are "Make bridgeless the default when the New Arch is enabled" for both Android and iOS in the v0.74.0 section.
[^3]: "Turbo Native Modules". React Native Documentation. [https://reactnative.dev/docs/next/turbo-native-modules-introduction](https://reactnative.dev/docs/next/turbo-native-modules-introduction)
[^4]: "Using Codegen". React Native Documentation. [https://reactnative.dev/docs/next/the-new-architecture/using-codegen](https://reactnative.dev/docs/next/the-new-architecture/using-codegen)
[^5]: "Fabric Renderer". React Native Documentation. [https://reactnative.dev/architecture/fabric-renderer](https://reactnative.dev/architecture/fabric-renderer)
[^6]: `RCTIsNewArchEnabled` always returns `YES`; `RCTSetNewArchEnabled` is a no-op. Source: `packages/react-native/React/Base/RCTUtils.mm:46-55`.
[^7]: `NewArchitectureHelper.new_arch_enabled` returns `true`. Source: `packages/react-native/scripts/cocoapods/new_architecture.rb:162-164`.
[^8]: Examples: `RCTAppDelegate.h`, `RCTReactNativeFactory.h`, `RCTAppSetupUtils.h` carry `deprecated(... will be removed when removing the legacy architecture)`. `RCTArchConfiguratorProtocol.h` was removed from public headers on the v0.87 line.
[^9]: `class BridgelessNativeModuleProxy : public jsi::HostObject` and `TurboModuleBinding::install` source: `packages/react-native/ReactCommon/react/nativemodule/core/ReactCommon/TurboModuleBinding.cpp:20-84,117-160`.
[^10]: `RCTEnableTurboModuleInterop(YES)` is invoked unconditionally in Bridgeless host setup. Source: `packages/react-native/Libraries/AppDelegate/RCTRootViewFactory.mm:150-156`.
[^11]: `ReactNativeNewArchitectureFeatureFlagsDefaults` sets `useTurboModuleInterop()` to `true`. Source: `packages/react-native/ReactAndroid/src/main/java/com/facebook/react/internal/featureflags/ReactNativeNewArchitectureFeatureFlagsDefaults.kt:30`.
[^12]: `ObjCInteropTurboModule` (iOS) and `JavaInteropTurboModule` (Android) wrap legacy modules. Sources: `packages/react-native/ReactCommon/react/nativemodule/core/platform/ios/ReactCommon/RCTInteropTurboModule.{h,mm}` and `.../platform/android/ReactCommon/JavaInteropTurboModule.{h,cpp}`.
[^13]: `LegacyViewManagerInterop*` files under `packages/react-native/ReactCommon/react/renderer/components/legacyviewmanagerinterop/`, plus `RCTLegacyViewManagerInteropCoordinator` for iOS.
[^14]: Source: `packages/rn-tester/NativeCxxModuleExample/NativeCxxModuleExample.{h,cpp,js,podspec}`.
[^15]: `TurboModuleRegistry.getEnforcing` uses `invariant(module != null, ...)`. `TurboModuleRegistry.get` returns `?T`. Source: `packages/react-native/Libraries/TurboModule/TurboModuleRegistry.js:35-47`.
[^16]: `TurboModuleBinding::getModule` runs the provider lazily and attaches a `jsRepresentation` whose property accesses defer to `TurboModule::get`. Source: `packages/react-native/ReactCommon/react/nativemodule/core/ReactCommon/TurboModuleBinding.cpp:170-218`.
[^17]: `RCTTurboModuleEnabled` / `RCTEnableTurboModule` declared deprecated in `packages/react-native/React/Base/RCTBridge.h:50-53`. Implementation always returns `YES` / no-op: `packages/react-native/React/Base/RCTBridge.mm:189-197` (commits `aee4a2586e`, `feede1422b`). The `useTurboModules` feature flag was removed entirely in v0.87.0-rc.0 (`b4a715ca1f`).
[^18]: CHANGELOG v0.87.0-rc.1 Strict TypeScript API default (`c948b61c05`). Opt-out: Metro `customConditions: ["react-native-legacy-deep-imports"]`.
[^19]: CHANGELOG v0.87.0-rc.0: "Remove deprecated `InteractionManager`" (`ed893f7d98`).
