# Changelog

All notable changes to this book are documented here.

The format is loosely based on [Keep a Changelog][kac]. Versions track the
React Native version the book is **verified against**, not a book-internal
version number. Tags in this repo match the corresponding RN tag (e.g. tag
`v0.87.0-rc.3` on the refresh that grounded the book in RN
`v0.87.0-rc.3` source).

[kac]: https://keepachangelog.com/en/1.1.0/

Detailed per-chapter audit history lives in each chapter's YAML frontmatter
`taillog` field. The audit workspace (`_verification/`, gitignored) holds
the per-chapter claims, source citations, runnable tests, and reports the
audit produced.

---

## [Unreleased]

### Changed

- Repo renamed to `gastonmorixe/react-native-new-architecture-book`
  (was `react-native-new-architecture-research`). README title is now
  "The React Native New Architecture Book".
- Chapter files renumbered to start at `01-` (were `00-` to `17-`, now
  `01-` to `18-`). The file prefix now matches the chapter number in
  each H1 and in the README table of contents. Chapter text did not
  change.
- Chapter 13 (Vision Camera): two "see Chapter 13" cross-references for
  Nitro now point to Chapter 14.

## [0.88.1] - 2026-10-29

Source-grounded refresh against React Native `main` at
`9c7b0f5fafd` (v0.88.1 era). The delta since `ca750feefb1` covers
`v0.87.0`, `v0.87.1`, the 0.88 RC train, `v0.88.0`, `v0.88.1`, and 795
commits on `main` after `v0.88.1`. Nine workers checked the chapters in
parallel against the source. Each chapter `taillog` has the detail.

### Added

- Chapter 2 (JSI): new `IRuntime` error factories (`createError` and
  typed variants), `IRuntime::length(String)`, and the `JSError`
  and `Value::toString` behavior changes.
- Chapter 3 (Fabric): `ShadowTreeCommitSource`, the React-branch commit
  path, the `RawPropsKeyMap` replacement of `RawPropsKey`, the
  iterator-setter `cloneProps` path, the differ unflatten flag removal,
  live-region Views no longer flattened, and prepared text layout on by
  default.
- Chapter 4 (TurboModules) and Chapter 5 (CodeGen): Java/Kotlin
  `ArrayBuffer` support in v0.88.0 with its borrow contract. Codegen
  discovery fixes.
- Chapters 6, 11, 12: the `RCT_REMOVE_LEGACY_MODULE_INTEROP` and
  `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` gates are opt-in from CocoaPods
  and SwiftPM since v0.88.0. They default to off.
- Chapter 13 (Vision Camera): v5.2.4 snapshot with the Nitro 0.37.0 pin.
- Chapter 14 (Nitro): stable `v0.37.1`. Mention of the
  `v1.0.0-alpha` nightlies. Nitrogen 0.37.1 re-run on the toy spec.

### Changed

- Verified-against version bumped from `v0.87.0-rc.3+main` /
  `ca750feefb1` to `v0.88.1+main` / `9c7b0f5fafd` across all chapter
  frontmatter, README, and NOTES.
- React peer dependency is now `^19.3.0` (reconciler 19.3.0).
- Strict TypeScript API default is dated `v0.87.0` (CHANGELOG.md:292),
  not `v0.87.0-rc.1`.
- `RCTTurboModuleEnabled()` and `RCTEnableTurboModule()`: they still
  exist in v0.88.1. Commit `01d55273bcf` deletes them on `main`.
- Chapter 6 (Bridgeless): `bridgelessEnabled` is gone from
  `RCTRootViewFactoryConfiguration`. The bridge proxy path in
  `RCTInstance.mm` replaced `setCurrentBridge`.
- Chapter 7 (Migration): iOS template snippet is `SceneDelegate` based.
  Tooling values: AGP 9.2.1, Kotlin 2.3.21, Gradle 9.4.1, `compileSdk`
  37, `minCompileSdk` 34, current Node engines range.
- Many footnote line references moved and were re-numbered.

### Fixed

- Chapters 4, 5, 8, 14, 16: the claim that Java/JNI codegen rejects
  `ArrayBuffer` is now false. Only `Promise<ArrayBuffer>` is rejected
  (`modules/Utils.js:95`).
- Chapter 8 (Performance): `RCTCxxBridge.mm` was removed in v0.87.0
  (`86350ab9884`). The citation now points at tag `v0.86.3`.
- Chapter 15 (Tutorial): `RCTImageViewManager.mm` no longer exists.
  `RCTPromiseResolveBlock` and `RCTPromiseRejectBlock` are `_Nullable`.
- Chapter 16 (Resources): `ModelCodegenConfig.kt` has no `ios` field.
  The popup-menu build file is `build.gradle.kts`.
- URLs checked: reactnative.dev and GitHub links return HTTP 200 or exist
  in a fresh `react-native-website` clone.

### New chapters

- Chapter 17 (`17-Interview-Questions.md`): 27 interview questions in five
  parts: architecture, runtime and JavaScript, UI and performance, native
  code and ecosystem, and testing. Each answer has a short spoken answer,
  key points, a common wrong answer, a follow-up, and source footnotes.
  Two fact-check workers re-verified Q1 to Q20 and fixed 11 errors.
  Examples: `Platform.OS` branches are removed from the bundle, FlashList
  claims were reworded to match its docs, and the AppState focus and blur
  note was proven.
- Chapter 18 (`18-Testing-React-Native-Apps.md`): unit and component
  tests, end-to-end tools, a dated history from 2015 to 2026, device
  clouds and CI, and agentic AI with MCP servers. Proofs run: a Jest and
  Testing Library test, Maestro `check-syntax` on two flows, a CI YAML
  parse, and `tools/list` on four MCP servers.

### Known open items

- Body headings count 1 to 16. File names and the frontmatter `chapter`
  field count from 00. This offset is by design.
- Code samples were not recompiled. Generated codegen output was not
  re-run for chapters 4 and 5.
- Third-party benchmark numbers were not re-measured.
- Nitro 1.0 alpha was not diffed.
- Chapter 18: no proof that Detox works on RN 0.88. Its README lists 0.77
  to 0.84, and two issues about RN 0.85 stay open. No test ran on a real
  device or simulator. Cloud pricing cells and the Sauce Labs, mabl and QA
  Wolf claims are unverified. Calabash and Frank dates are unverified.
- Chapter 17: the Hermes sampling profiler has no docs page, so that claim
  stays marked unverified. The Expo SDK 58 upgrade guide was not fetched.

---

## [0.87.0-rc.3] - 2026-07-28

Source-grounded refresh against React Native `main` at
`ca750feefb1` (v0.87.0-rc.3 era), covering the delta since
`v0.86.0-rc.2` through `v0.86.2` stable and the full 0.87 RC train
(`v0.87.0-rc.0`…`v0.87.0-rc.3`).

### Added

- Chapter 4 (TurboModules): first-class `ArrayBuffer` bridging section
  for C++ and ObjC (C++ `ReactCommon/react/bridging/ArrayBuffer.h`,
  ObjC `NSData` converters). Notes that Java/JNI CodeGen still rejects
  `ArrayBuffer`. Cites commits `226ef2e7c5` / `54b88d9dea`.
- Chapter 6 (Bridgeless): v0.87 status on interop compile-out gates
  (`RCT_REMOVE_LEGACY_MODULE_INTEROP`,
  `RCT_REMOVE_LEGACY_COMPONENT_INTEROP`).
- Chapter 7 (Migration): 0.87 tooling requirements (AGP v9, Gradle
  9.4.x, Kotlin ≥ 2.0, Node ≥ 22.13, `compileSdk` 37) and Strict
  TypeScript API default (`customConditions:
  ["react-native-legacy-deep-imports"]` opt-out).
- Chapter 8 (Performance): callout for C++ Native Animated canary
  (`cxxNativeAnimatedEnabled`, `ossReleaseStage: 'canary'`,
  `expectedReleaseValue: true`) and ArrayBuffer TurboModule payloads.
- Chapter 9 (Conclusion): roadmap bullets for legacy deletion,
  ArrayBuffer TurboModules, C++ Native Animated, Strict TS API, Yoga
  §4.5 auto min-size.
- Chapter 16 (Resources): checklist items for Strict TS API imports
  and `ArrayBuffer` binary payloads; interop compile-out as a migration
  challenge.

### Changed

- Verified-against version bumped from `v0.86.0-rc.1` /
  `b32a6c9e9db` to `v0.87.0-rc.3+main` / `ca750feefb1` across all
  chapter frontmatter, README, and NOTES.
- TurboModules framing: "default since 0.76" → "**always on** as of
  0.87" (`useTurboModules` flag removed; `RCTTurboModuleEnabled()`
  always `YES` and deprecated).
- Bridgeless / future: `RCTArchConfiguratorProtocol` is no longer a
  deprecated public header — it was **removed** on the v0.87 line.
- FAQ Q1 rewritten: corrected the stale "you can still opt out via
  gradle.properties / Podfile" claim (false since 0.82; the prior
  0.86 audit left this regression in FAQs).

### Fixed

- Introduction still claimed opt-out was available via Chapter 7
  procedures; rewritten for 0.82 removal + 0.87 hard-wiring.
- Conclusion still claimed an opt-out flag "still exists"; corrected.
- FAQ / Best Practices / Common Mistakes version-context lines updated
  off the 0.86-era wording that implied opt-out or feature-flag-only
  interop gating.
- Chapter 14 (Nitro): corrected the stale "ArrayBuffer … none directly
  supported by RN codegen" claim — C++/ObjC codegen support it as of
  0.87; Java/JNI still reject.
- Chapter 5 (CodeGen): added v0.87 platform matrix for `ArrayBuffer`
  and note that pure-C++ modules no longer need
  `includesGeneratedCode: true`.
- Chapter 3 (Fabric): noted `RawPropsKey` prefix/suffix removal
  (`67381e157f`).
- Chapter 9 (Conclusion): View Transitions (0.86) +
  `InteractionManager` → `requestIdleCallback` (0.87).

---

## [0.86.0-rc.1] - 2026-05-23

Comprehensive source-grounded audit pass against React Native at upstream
HEAD `b32a6c9e9db` (v0.86.0-rc.1 era), with cross-checks against
`react-native-vision-camera` v5.0.10 (`5a07d7ae`), `nitro` v0.35.7
(`326d3e4b`), and the `facebook/react-native-website` repo (`a263a3ba`).

Net delta: 18 files changed, ~2,287 insertions, ~840 deletions, ~120 new
source-grounded footnotes, full YAML frontmatter on every chapter.

### Added

- YAML frontmatter on all 18 chapter files (chapters 1-16 plus `README.md`
  and `NOTES.md`). Fields: `title`, `chapter`, `created_at`, `updated_at`,
  `rn_version_origin`, `rn_version_current`, `tags`, `audit`, `taillog`.
  Frontmatter schema in `_verification/shared/yaml-frontmatter-schema.md`
  (audit workspace).
- ~120 source-grounded footnotes across all chapters. Each cites a specific
  RN source path with line numbers, a CHANGELOG entry, or an external
  source. Footnote pattern is the existing `[^N]` style.
- Chapter 13 (Vision Camera): new paragraph on v5.0 (April 2026) which
  switched Frame from a `jsi::HostObject` to a Nitro `HybridObject`,
  deleting ~2,970 lines of in-tree JSI code. Cites the v5 PR commit
  (`30a8b5de`).
- Chapter 14 (Nitro): the actual `loadHybridMethods` body inlined from
  running nitrogen 0.35.7 end-to-end on a hand-rolled `Math.nitro.ts`
  spec. 21 generated files were captured for the recheck artifact set.
- Chapter 8 (Performance Analysis): a "Status as of v0.86 (2026)" callout
  clarifying that the chapter's "React 18 concurrent features" framing
  still holds, but RN's actual peer dep is now `react ^19.2.3`.
- This `CHANGELOG.md` and a proper repo `.gitignore`.

### Changed

- React 18 → React 18+/React 19 framing across chapters 1, 3, 8, 9. RN
  moved to React 19 in v0.78 (Feb 2025); current `main` pins
  `"react": "^19.2.3"`. The capability set the book describes is still
  correct, only the version label needed updating.
- Multiple C++/Objective-C++ code samples rewritten to compile against
  the actual RN source:
  - Chapter 2 (JSI): five hard signature errors in JSI snippets, plus one
    pre-existing overload-resolution bug.
  - Chapter 3 (Fabric): `ShadowNode` layout, `ComponentDescriptor` API
    (`cloneProps` `PropsParserContext` arg), `ShadowTree::tryCommit`
    locking, iOS mount path attribution, Yoga integration shape.
  - Chapter 5 (CodeGen): the "generated header" example invented
    `NativeMyModuleSpecJSI : public TurboModule` with virtuals. Real
    codegen emits three distinct shapes (iOS ObjC++ protocol + SpecJSI
    shim, Android Java/Kotlin abstract class + JNI SpecJSI shim, pure
    C++ CRTP `CxxSpec` template), none of which use C++ virtuals to
    enforce the contract. Section rewritten around the real artifacts.
  - Chapter 15 (Tutorial): iOS Promise signature was fabricated
    (`Promise<NSString *> &resolve`). Real codegen uses
    `RCTPromiseResolveBlock` / `RCTPromiseRejectBlock`. Android sections
    updated for `BaseReactPackage` (replacing the now-deprecated
    `TurboReactPackage`), corrected `Native<HasteBasename>Spec`
    abstract-class naming, 6-arg `ReactModuleInfo` constructor, Fabric
    `componentDescriptorProvider` + `<Name>Cls(void)` requirement.
- Chapter 13 (Vision Camera) reframed as a counter-example: VC v4 used
  `requireNativeComponent` (legacy Paper) and `RCTViewManager`, running
  under New Arch only via the interop layer. v5 (April 2026) is the
  proper New Arch implementation; the chapter now reflects both.
- Chapter 14 (Nitro): performance numbers replaced. The fabricated
  "2.5x/2.1x faster, 30% less memory" was swapped for the real published
  benchmark numbers (~16x on `addNumbers`, ~6x on `addStrings` synthetic
  100k-call loops), which Nitro itself flags as extreme cases.
- Chapter 7 (Migration): "Important Note" rewritten. Opt-out was removed
  in v0.82 (released 2025-10-07). Both Android (`newArchEnabled=false`)
  and iOS (`RCT_NEW_ARCH_ENABLED=0`) are now force-overridden by the
  build/install tooling. The C helper `RCTIsNewArchEnabled()` is
  hard-wired to `YES`.
- All 16 chapter H1 headings restored to sequential `Chapter 1`..
  `Chapter 16`, in lockstep with the README's table of contents. Three
  files had off-by-one duplicates pre-audit, and the recheck phase caught
  one regression that re-introduced a duplicate.

### Fixed

- Wrong iOS symbol name: `RCTIsNewArchitectureEnabled` (does not exist in
  RN source) → `RCTIsNewArchEnabled` (declared at
  `packages/react-native/React/Base/RCTUtils.h:18`). Fixed in chapters
  12 (FAQs), 16 (Resources), `NOTES.md`.
- Multiple broken footnote URLs:
  - Chapter 9 (Conclusion): both `[^1]` and `[^2]` returned 404. Replaced
    with verified-200 canonical URLs and split into 7 footnotes.
  - Chapter 12 (FAQs): `[^1]` and `[^5]` were dead.
  - Chapter 14 (Nitro): all six original footnote paths were stale after
    Nitro's docs reorganization into `getting-started/`, `concepts/`,
    `resources/`, `types/`.
- Three `reactnative.dev` URLs in chapter 7 that vercel.json redirects
  off-site to `github.com/reactwg/...`. Replaced with the canonical
  `turbo-native-modules-introduction` and `fabric-native-components-
  introduction` slugs the rest of the book already uses.
- One internal-redirect URL in chapter 12 (FAQs) updated to canonical
  `/architecture/landing-page`.
- Chapter 3 (Turbo Modules) footnote rendering: body referenced `[1]` /
  `[2]` but the citations block used `[^1]` / `[^2]`, so cross-links did
  not render. Normalized to the markdown footnote syntax.
- "Refined" precision on two Nitro chapter claims:
  - "Generic `Repository<T>` won't parse" was too strong. Actual nitrogen
    0.35.7 behavior is to parse it fine and fail at codegen with
    `Error: The TypeScript type "T" cannot be represented in C++!`.
    Reproducible by the audit's toy spec.
  - "TurboModule cannot be cached" was too strong. `TurboModule::get()`
    in `TurboModule.h:50-65` writes the resolved method back onto the JS
    representation via `setProperty`; subsequent accesses skip the native
    callback. The Nitro win is the prototype is installed once *per
    type*, not lazily after first access.
- Vision Camera chapter 13 citations:
  - Path `package/docs/...` was always wrong (`docs/` lives at the repo
    root). Correct path used.
  - Off-by-one line citation: `FrameHostObject.cpp:23` is blank;
    correct line is `:22`.
  - Undercount: `Four such TODO: ... TurboModules comments` → actual is
    7 in v4.7.2's `package/`, plus 2 non-TODO references.
- HostObject destructor language in chapter 10 (Common Mistakes): the
  original said "explicitly unsafe to make any JSI calls from within the
  destructor". The canonical JSI source comment
  (`jsi/jsi/jsi.h:222-233`) is narrower — operations taking a `Runtime&`
  are unsafe; destructing other jsi objects is explicitly allowed.
- TurboModule callbacks vs Promises in chapter 11 (Best Practices). The
  original said callbacks "may be supported by the interop layer", which
  is wrong: a `(arg: T) => void` parameter is a first-class TurboModule
  signature, parsed as `FunctionTypeAnnotation`, generated as
  `jsi::Function`, and used by current core specs like `NativeMicrotasks`
  and `NativeIdleCallbacks`. Promises are still recommended but for
  ergonomics, not because callbacks are unsupported.
- Fabric `updateProps` framing in chapter 11. "A diffing mechanism" was
  misleading. On iOS the method receives both `props` and `oldProps` and
  the view does the diff by hand. On Android the wrapper is a pre-
  filtered `ReactStylesDiffMap` containing only changed keys.

### Removed

- Three hallucinated Nitro features that appeared nowhere in Nitro's
  docs or source: "Hot Reload Support for native code", "IDE
  Integration", "Better Error Messages with stack traces". Each was
  removed and the chapter now documents what Nitro actually does.

### Infrastructure

- Added `.gitignore` covering: OS metadata (`.DS_Store`), editor configs
  (`.vscode/`, `.idea/`), audit workspace (`_verification/`), minimal-
  agent debug dumps (`.net-dbg/`), lockfiles (`bun.lock`, `*.lock`),
  common build outputs and caches, env files.
- Established two long-lived audit branches:
  - `audit/baseline-2026-05-23` — pre-audit snapshot of all in-progress
    edits (preserved as a safety net; do not delete unless rolling back
    is no longer needed).
  - `audit/verified-2026-05-23` — the audit result (this PR's branch).
- Tagged `v0.86.0-rc.1` on the audit HEAD to indicate the RN version the
  book is verified against.

### Methodology

The audit was carried out by 21 parallel `minimal-agent --effort max`
workers (Claude Opus 4-7) inside a shared tmux session `ma-rn-arch-audit`,
managed by a coordinator session. Each worker owned one chapter (Phase 2,
18 workers) or one external repo cross-check (Phase 5, 3 workers).

- Phase 0: workspace + baseline branch setup.
- Phase 1: triage (chapter heading inventory).
- Phase 2: 18 workers, one per chapter, ~36 min wall clock. Each worker
  extracted claims, verified against RN source + CHANGELOG, wrote and
  ran tests on every code sample, then edited the chapter.
- Phase 3: manager-level cross-chapter consistency pass (fixed 4 H1
  numbering bugs).
- Phase 4: master delta report + first audit commit.
- Phase 5: 3 specialized workers re-checking VC, Nitro, and docs URLs
  against the synced external repos. Manager applied docs-URL fixes
  and caught one chapter numbering regression.

Tests written and executed during the audit include: `tsc --strict`
type-checks on chapter TS specs, Mermaid syntax validation on all
embedded diagrams, RN CodeGen round-trip on chapter examples (chapter 4),
nitrogen 0.35.7 round-trip on a toy spec (chapter 14).

---

## [0.81.4] - 2025-09-22

Initial bootstrap of the book. Closest stable RN release at the time was
v0.81.4 (released 2025-09-10).

### Added

- A 16-chapter deep-dive report on the React Native New Architecture
  authored from a combination of the official RN source, RN blog posts,
  community libraries (Vision Camera, Reanimated), and Nitro framework
  docs.
- Initial structure:
  - **Part 1 — Core Architecture**: Introduction (the "why"), JSI, Fabric,
    TurboModules, CodeGen, Bridgeless.
  - **Part 2 — Practical Application & Guides**: Migration & adoption,
    performance analysis, conclusion & future, common mistakes, best
    practices, FAQs.
  - **Part 3 — Real-World Examples & Tooling**: Vision Camera case study,
    Nitro alternative tooling, hands-on tutorial, additional resources
    & checklists.
- Mermaid diagrams for Bridge vs JSI call paths, Fabric's render
  pipeline, TurboModule + CodeGen pipeline, Bridgeless interop,
  migration flow.
- `LICENSE` (MIT), `README.md` table of contents, `NOTES.md` author
  logbook.
