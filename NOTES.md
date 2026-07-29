---
title: "Research session notes"
chapter: "NOTES"
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
tags: [react-native, new-architecture, logbook, audit, meta]
audit:
  status: "verified"
  baseline_branch: "audit/baseline-2026-05-23"
  verified_branch: "audit/verified-2026-05-23"
  report: "_verification/chapters/notes/report.md"
taillog:
  - "2025-09-22T15:30:19-04:00 | Initial draft (RN 0.81.4 era)"
  - "2026-05-23T16:15:34-04:00 | Source-grounded audit pass against RN 0.86 (commit b32a6c9e9db). Original logbook preserved verbatim. Added an audit annotations section flagging two stale facts: the opt-out flow was removed in v0.82, and the symbol the author 'corrected to' (`RCTIsNewArchitectureEnabled`) does not exist (actual symbol is `RCTIsNewArchEnabled`). See _verification/chapters/notes/report.md."
  - "2026-07-28T22:15:00-04:00 | Refresh against RN main ca750feefb1 (v0.87.0-rc.3 era). Documented TurboModules always-on, legacy interop compile-out gates, ArrayBuffer TurboModule support, Strict TypeScript API default, C++ Native Animated canary, and corrected remaining opt-out claims."
---

# Research session notes

This file is the original author's running logbook from the
2025-09-22 / 2025-09-23 research-and-rewrite session. It is preserved
verbatim below for the historical record. The "Audit annotations" section
is a 2026-05-23 audit pass against RN HEAD (~v0.86.0-rc.1) and flags two
facts in the log that no longer hold (or never did). The "0.87 refresh
annotations" section at the bottom records the 2026-07-28 update against
`ca750feefb1` (v0.87.0-rc.3 era).

## Original logbook (preserved)

2025-09-22 18:53
- Starting task: prepare repo for initial commit; remote fetch failed due to repository not found.

2025-09-22 20:12
- Created initial commit and attempted push; origin path reports repository not found.

2025-09-22 20:19
- Fetched corrected origin, rebased local bootstrap commit onto origin/main, and pushed main successfully.

2025-09-23 00:01
- Reviewed staged chapter renames and README TOC update; preparing final commit and push.

2025-09-23 00:38
- Reviewing 06-Migration-And-Adoption.md guidance against upstream codebase and latest docs before updating recommendations.

2025-09-23 00:45
- Updated migration guide to drop deprecated :new_arch_enabled flag, document default enablement, and show opt-out flow.

2025-09-23 00:48
- Beginning sequential review of all research chapters against upstream repo and next docs.

2025-09-23 00:58
- Completed chapter-by-chapter alignment with repo and next docs; updated citations, case study details, Nitro coverage, tutorial fixes, and resource checklist.

2025-09-23 01:05
- Corrected checklist to reference RCTIsNewArchitectureEnabled().

2025-09-23 04:58
- Converted chapter citations to footnotes for proper anchor navigation.

## Audit annotations (2026-05-23, RN 0.86.0-rc.1+main @ b32a6c9e9db)

Two entries above were true (or true-enough) on 2025-09-23 against
RN 0.81.4 but are now misleading. Both are flagged here rather than
edited out, because the logbook is a historical artifact.

### 1. The "show opt-out flow" entry (2025-09-23 00:45) is now stale

The original migration-guide edit advertised an opt-out path
(`newArchEnabled=false` on Android, `RCT_NEW_ARCH_ENABLED=0` on iOS).
That path was correct under RN 0.81.4. **It was removed in RN 0.82.**

Concretely, at the audited HEAD:

- Android: `DefaultReactNativeHost.kt` errors out if a subclass
  overrides `isNewArchEnabled` to anything other than the default
  `true`, with the message *"Overriding isNewArchEnabled to false is
  not supported anymore since React Native 0.82. Please check your
  MainApplication.kt file, and remove the override for
  `isNewArchEnabled`."*[^audit-1]
- iOS Podfile: `react_native_pods.rb` force-sets
  `ENV["RCT_NEW_ARCH_ENABLED"] = "1"` inside `use_react_native!`, and
  the `warn_if_new_arch_disabled` helper prints *"WARNING: Calling pod
  install with `RCT_NEW_ARCH_ENABLED=0` is not supported anymore since
  React Native 0.82."*[^audit-2]
- iOS runtime: `RCTIsNewArchEnabled()` is now defined as `return YES;`
  in `RCTUtils.mm`, with no Info.plist read on the hot path.[^audit-3]
- The `RCTSetNewArchEnabled(BOOL)` setter is `__attribute__((deprecated))`
  and a no-op.[^audit-4]

The original move from `0.82.0-rc.0` is in CHANGELOG.md under v0.82.0:
*"New Architecture: Remove possibility to newArchEnabled=false in
0.82"* (`d5d21d0614` by @cortinico) and *"New Architecture: Removed
the opt-out from the New Architecture."* (`83e6eaf693` by
@cipolleschi).[^audit-5]

For consumers on the current `main` line, the only "opt-out" is to
stay on a `0.81.x` (or earlier) tag.

### 2. The "Corrected checklist to reference RCTIsNewArchitectureEnabled()" entry (2025-09-23 01:05) names a symbol that does not exist

The exported iOS C API is `RCTIsNewArchEnabled()` (no "itecture" in
the middle), declared in `RCTUtils.h:18` as
`RCT_EXTERN BOOL RCTIsNewArchEnabled(void);` and defined in
`RCTUtils.mm:46-49`.[^audit-3]

`RCTIsNewArchitectureEnabled()` is not present anywhere in the RN
public surface and never has been. It was introduced under the
shorter name in PR #42090 (`f1a7f08feb2`, 2024-01-02), first released
in `v0.74.0`.[^audit-6]

The downstream effect of that "correction" was that
`15-Additional-Resources-and-Checklists.md` briefly referenced the
nonexistent symbol. **Fixed in the 2026-05-23 audit** — chapter 16 now
correctly cites `RCTIsNewArchEnabled()`. This note remains only as the
upstream cause of the historical logbook typo.

---

**Audit footnotes:**

[^audit-1]: `packages/react-native/ReactAndroid/src/main/java/com/facebook/react/defaults/DefaultReactNativeHost.kt:42-48` and `:71-79`. Same error string is raised from both the TurboModule-delegate and UIManager-provider entry points.

[^audit-2]: `packages/react-native/scripts/react_native_pods.rb:116` (the force-set) and `:474-490` (the warning). The warning helper is named `warn_if_new_arch_disabled`.

[^audit-3]: `packages/react-native/React/Base/RCTUtils.h:18` and `packages/react-native/React/Base/RCTUtils.mm:46-49`.

[^audit-4]: `packages/react-native/React/Base/RCTUtils.h:19-21` and `RCTUtils.mm:50-55`. The `__attribute__((deprecated(...)))` message is *"This function is now no-op. You need to modify the Info.plist adding a RCTNewArchEnabled bool property to control whether the New Arch is enabled or not."* That guidance itself is now historical: the live `RCTIsNewArchEnabled()` does not consult Info.plist at HEAD.

[^audit-5]: Both entries are in the `## v0.82.0` section of `CHANGELOG.md` at the RN repo root. The introducing commits (`d5d21d061493ee973c789a7c6ab8cceebc1f04f9` and `7d0bef2f25a206d917e7f5cc2b9a6c088f13a832`) land on `0.82.0-rc.0`.

[^audit-6]: `git log -1 --format='%H %s' f1a7f08feb2` returns *"Add functions to check whether the New Arch is enabled at runtime (#42090)"*; `git tag --contains f1a7f08feb2 | sort -V | head -1` returns `v0.74.0`.

---

## 0.87 refresh annotations (2026-07-28, RN 0.87.0-rc.3+main @ ca750feefb1)

Refresh scope: `v0.86.0-rc.2` → `main` (`ca750feefb1`), including
`v0.86.0`…`v0.86.2` and `v0.87.0-rc.0`…`v0.87.0-rc.3`.

### Net New Architecture story since the 0.86 audit

1. **TurboModules are always enabled.** The `useTurboModules` feature
   flag was removed (`b4a715ca1f`). `RCTTurboModuleEnabled()` always
   returns `YES`; `RCTEnableTurboModule()` is a deprecated no-op
   (`aee4a2586e`, `feede1422b`).
2. **Legacy interop is compile-gated for deletion.**
   `RCT_REMOVE_LEGACY_MODULE_INTEROP` and
   `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` wrap the remaining
   `ObjCInteropTurboModule` / `LegacyViewManagerInterop*` surfaces
   (`3278f309e2`, `9885fe95ef`).
3. **Legacy architecture deletion accelerated on iOS.**
   `RCTArchConfiguratorProtocol` public header gone; further
   `RCTCxxBridge` / AppSetup / bridge-era TurboModule manager
   initializers removed under `RCT_REMOVE_LEGACY_ARCH`
   (`2148f15db5`, `ad9936faf6`, `86350ab988`, `c65281581d`).
4. **`ArrayBuffer` is a first-class TurboModule bridging type** for
   C++ and ObjC (`226ef2e7c5`, `54b88d9dea`).
5. **Strict TypeScript API is the default JS surface** as of
   0.87.0-rc.1 (`c948b61c05`). Temporary opt-out:
   `customConditions: ["react-native-legacy-deep-imports"]`.
6. **C++ Native Animated** (`cxxNativeAnimatedEnabled`) sits on the
   canary OSS stage with `expectedReleaseValue: true`; stable defaults
   still return `false` in `ReactNativeFeatureFlagsDefaults`.
7. **Tooling floor for 0.87 apps:** Node ≥ 22.13.0, AGP v9, Gradle
   9.4.x, Kotlin ≥ 2.0, `compileSdk` 37.

### Regression caught in the prior audit

FAQ Q1 still claimed (as of the 0.86 pass) that opt-out via
`newArchEnabled=false` / `RCT_NEW_ARCH_ENABLED=0` worked. That was
already false since 0.82; Chapter 7 had the correct story, FAQs did
not. Fixed in this refresh.
