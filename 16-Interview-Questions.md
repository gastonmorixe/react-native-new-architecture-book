---
title: "Top 27 React Native interview questions"
chapter: "16"
created_at: "2026-10-29T13:00:00-04:00"
updated_at: "2026-10-29T13:00:00-04:00"
rn_version_origin:
  version: "0.88.1"
  tag: "v0.88.1"
  date: "2026-10-27"
  note: "Chapter written during the 2026-10-29 refresh."
rn_version_current:
  version: "0.88.1+main"
  tag: "v0.88.1"
  commit: "9c7b0f5fafdaa986bd3dcff7d65c3d8d59861176"
  date: "2026-10-29"
  note: "Upstream RN main HEAD as of the refresh. Includes v0.88.1 stable; main is 795 commits past it."
tags: [react-native, interview, new-architecture, hermes, fabric, turbomodules, performance]
audit:
  status: "partial"
taillog:
  - "2026-10-29T13:00:00-04:00 | New chapter. Four research workers wrote 5 questions each against RN v0.88.1 source. Fact-check pass pending."
  - "2026-10-29T16:00:00-04:00 | Two adversarial fact-check workers re-verified Q1 to Q20 (about 195 claims, 11 errors fixed). Q21 to Q27 (testing) added and re-verified with commands. Open items are in the CHANGELOG."
---

# Chapter 17: Top 27 React Native Interview Questions

Use this chapter to prepare for a senior React Native interview. Each answer starts with a short spoken answer. Key points, a common wrong answer, and a likely follow-up come next. Every fact has a footnote with a source path, a changelog line, or a URL. All facts are checked against React Native v0.88.1 and `main` at `9c7b0f5fafd`, unless a note says otherwise.


## Part 1: Architecture

### Q1. What is the React Native New Architecture, and what problem does it solve?

**Short answer (say this first, 2 to 4 sentences):** The New Architecture is the current runtime of React Native. It replaces the old asynchronous Bridge with JSI, and it uses Fabric for rendering and TurboModules for native modules. JS can now call native code directly and synchronously when needed, and React can render with concurrent features. In 0.88 it is the only supported mode, not an option.[^iq1-1][^iq1-2]

**Key points:**
- Four parts: JSI (the C++ interface to the JS engine), Fabric (renderer), TurboModules (native modules), Codegen (type-safe glue from specs).
- The old design sent batched messages across the Bridge. The new design lets JS hold references to native objects.[^iq1-3]
- It has been mandatory since 0.82. Android ignores `newArchEnabled=false` and logs an error.[^iq1-2][^iq1-4]
- On iOS, `pod install` with `RCT_NEW_ARCH_ENABLED=0` prints a warning and the app still runs with the New Architecture.[^iq1-5]
- The Bridgeless feature flag `enableBridgelessArchitecture` defaults to `true`.[^iq1-6]

**Example or code (only when it helps, max 15 lines):**
```properties
# android/gradle.properties (0.88 template style). Not compiled.
newArchEnabled=true
hermesEnabled=true
```

**Common wrong answer:** "The New Architecture is experimental and you can turn it off." Wrong: it has been the only mode since 0.82.

**Likely follow-up:** Is it faster in every case? No. It removes Bridge serialization and enables concurrent React. Real gains depend on the app.

### Q2. How did the old Bridge work, and how does JSI change that?

**Short answer (say this first, 2 to 4 sentences):** The old Bridge queued native calls in JS (`MessageQueue`) and flushed them in batches to native. Native replied through callbacks and events. JSI is a C++ API over the JS engine. With JSI, native code can install host objects and host functions that JS calls directly, with no queue between them. The Bridge JS file is now marked deprecated.[^iq2-1][^iq2-2][^iq2-3]

**Key points:**
- `MessageQueue.js` batches calls. It uses a minimum flush gap `MIN_TIME_BETWEEN_FLUSHES_MS = 5`.[^iq2-1]
- `BatchedBridge.js` still installs `global.__fbBatchedBridge`, but the file is tagged `@deprecated`.[^iq2-2]
- In `MessageQueue.js`, `JSON.stringify` appears only in the debug `spy` logger (line 99) and in an invalid-argument error message (line 309). It is not in the call path (`enqueueNativeCall`) in 0.88.[^iq2-1]
- JSI defines `jsi::HostObject` and `HostFunctionType`. Native code exposes them to JS.[^iq2-3]
- A TurboModule is itself a `jsi::HostObject`, so JS holds the native object directly.[^iq2-4]
- Interop: if the JSI proxy has no module, the registry falls back to `NativeModules`. Legacy modules still use that path.[^iq4-1]
- JSI is engine neutral. Hermes is the engine you ship (see Chapter on Hermes).

**Example or code (only when it helps, max 15 lines):**
```js
// JS side, simplified. TurboModuleRegistry asks the JSI proxy first.
const turboModuleProxy = global.__turboModuleProxy;
const module = turboModuleProxy != null ? turboModuleProxy(name) : null;
// Source: Libraries/TurboModule/TurboModuleRegistry.js (simplified)
```

**Common wrong answer:** "The bridge is async JSON, and JSI only makes it faster." Wrong: JSI removes the queue for the main paths. The call path in `MessageQueue.js` does not use `JSON.stringify`. Also, calls can be sync when the spec says so.

**Likely follow-up:** Is JSI always synchronous? No. A method returns a Promise or takes a callback when you want async. The spec decides.

### Q3. What is Fabric, and how is rendering different from the old UIManager?

**Short answer (say this first, 2 to 4 sentences):** Fabric is the C++ renderer. React builds an immutable shadow tree in C++. The renderer diffs the old and new trees into a list of mutations. Then it mounts those mutations on the UI thread. The old UIManager was a Java/Obj-C layer that got serialized commands over the Bridge.[^iq3-1][^iq3-2]

**Key points:**
- The shadow tree lives in C++ (`ShadowTree`) and is shared by iOS and Android.[^iq3-1]
- The differ turns two trees into `ShadowViewMutation` lists (`calculateShadowViewMutations`).[^iq3-2]
- JS reaches the renderer through the JSI global `nativeFabricUIManager`, wrapped in `FabricUIManager.js`.[^iq3-3]
- Layout runs in C++ with Yoga on the shadow tree, so JS can read layout synchronously (see the layout chapter).
- Old Paper classes were removed step by step. The 0.88 changelog lists removals such as `UIImplementation` and `RCTCxxBridge`.[^iq3-4]

**Example or code (only when it helps, max 15 lines):**
```js
// Public API users call. Fabric needs no code change in app JS.
import {View, Text} from 'react-native';
```

**Common wrong answer:** "Fabric is just a faster UIManager." Wrong: it is a new C++ pipeline with immutable trees and a shared core.

**Likely follow-up:** What does immutable mean here? Each commit makes a new tree. Old trees stay valid, so threads can read without locks.

### Q4. What is a TurboModule, and what does Codegen do?

**Short answer (say this first, 2 to 4 sentences):** A TurboModule is a native module that JS reaches through JSI. It loads lazily, when JS first asks for it. You describe its API in a typed JS spec file. Codegen reads that spec and generates the native interfaces in C++, Obj-C++, and Java. This way JS and native agree on types at build time.[^iq4-1][^iq4-2]

**Key points:**
- JS gets a module with `TurboModuleRegistry.get` or `getEnforcing`. The second one throws when the module is missing.[^iq4-1]
- If the JSI proxy has no module, the registry falls back to the old `NativeModules` lookup. This is the interop path.[^iq4-1]
- `TurboModule` in C++ derives from `jsi::HostObject`.[^iq4-3]
- Codegen generators for modules live in `packages/react-native-codegen/src/generators/modules`. They produce C++/JNI/Java and Obj-C++ output.[^iq4-2]
- The core package itself declares `codegenConfig` with a library `FBReactNativeSpec`.[^iq4-4]
- A wrong spec fails at build time, not at call time.

**Example or code (only when it helps, max 15 lines):**
```js
// NativeSampleModule.js (spec). Not compiled.
import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';
export interface Spec extends TurboModule {
  +add: (a: number, b: number) => number;
}
export default TurboModuleRegistry.getEnforcing<Spec>('SampleModule');
```

**Common wrong answer:** "Codegen runs at runtime and checks types as you call." Wrong: it runs at build time and generates native code.

**Likely follow-up:** Does a TurboModule load at app start? No. It loads lazily on first access.

### Q5. What is Bridgeless mode, and can I still use the old Bridge or opt out of the New Architecture in 0.88?

**Short answer (say this first, 2 to 4 sentences):** Bridgeless mode runs React Native with no Bridge instance. The runtime talks to JS through JSI only. In 0.88 you cannot opt out of the New Architecture. Legacy modules and legacy view managers still work through interop layers. Maintainers are removing even those step by step.[^iq5-1][^iq5-2]

**Key points:**
- Android: `newArchEnabled=false` gives an error and is ignored since 0.82.[^iq5-1]
- iOS: `RCT_NEW_ARCH_ENABLED=0` gives a warning and is ignored.[^iq5-2]
- `RCT_REMOVE_LEGACY_ARCH` defaults to `1` in the pod script, which compiles legacy code out. Setting it to `0` keeps some old code compiled. It does not turn the old Bridge back on.[^iq5-3]
- Interop switches `RCT_REMOVE_LEGACY_MODULE_INTEROP` and `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` are opt-in. Both default to off now. They are planned to become the default later.[^iq5-4]
- Old libraries often still run through the interop layer. Check each library before an upgrade.
- `BridgelessReactContext.getCatalystInstance()` is deprecated.[^iq5-5]

**Example or code (only when it helps, max 15 lines):**
```ruby
# Podfile. Not compiled. Opt in to strict removal of the interop:
ENV['RCT_REMOVE_LEGACY_MODULE_INTEROP'] = '1'   # name from CHANGELOG, check your Podfile docs
ENV['RCT_REMOVE_LEGACY_COMPONENT_INTEROP'] = '1'
```

**Common wrong answer:** "Set newArchEnabled=false to stay on the old Bridge until you are ready." Wrong since 0.82: the flag is ignored.

**Likely follow-up:** What breaks if a library is old? Its native code may need the interop layer or a migration to a TurboModule or Fabric component.

## Part 2: Runtime and JavaScript

### Q6. What is Hermes, why is it the default engine, and what is Hermes V1 and bytecode precompilation?

**Short answer (say this first, 2 to 4 sentences):** Hermes is an open-source JavaScript engine built for React Native. It is the default engine, so no setup is needed.[^iq6-1] In release builds, the build step compiles your JavaScript bundle to Hermes bytecode (HBC) ahead of time. The device loads bytecode, so startup is faster. Hermes V1 is the new generation of the engine, and it became the default in 0.84.[^iq6-2]

**Key points:**
- React Native ships a bundled Hermes, built for each React Native release, so engine and framework versions match.[^iq6-1]
- Hermes V1 became the default engine in 0.84.[^iq6-2] The `hermesV1Enabled` opt-in flag was removed in 0.87, so there is no switch to turn V1 off.[^iq6-3]
- The compiler is a separate npm package, `hermes-compiler`. At v0.88.1 it is pinned to `260318099.0.5`.[^iq6-4]
- Release builds compile JavaScript to bytecode at build time. Debug builds load JavaScript from Metro.[^iq6-5]
- The runtime and the compiler must match. A mismatch gives a "Wrong bytecode version" crash. A SwiftPM release build had this bug, fixed in 0.87.[^iq6-6]
- JavaScriptCore is not in core. You opt out of Hermes only through the community JavaScriptCore package.[^iq6-7]

**Example or code (only when it helps, max 15 lines):**
```js
// Runtime check. Not enough alone to prove you load bytecode.
const isHermes = () => !!global.HermesInternal;
```

**Common wrong answer:** "Hermes is optional, and JavaScriptCore is the default on iOS." Wrong. Hermes is the default on both platforms, and JavaScriptCore lives in a community package.[^iq6-1][^iq6-7]

**Likely follow-up:** How do you check that your release app uses bytecode? Make a release build and compare startup. `HermesInternal` can exist even when you load plain JavaScript, so also confirm the bundle is a `.hbc` file.[^iq6-8]

### Q7. Which threads does React Native use, and where does your JS, layout, and UI work run?

**Short answer (say this first, 2 to 4 sentences):** The renderer uses two main threads. The JavaScript thread runs your code, React's render phase, and layout. The UI (main) thread is the only thread that can change native views. Mounting runs on the UI thread, and the commit phase can run on a background thread.[^iq7-1][^iq7-3]

**Key points:**
- The UI thread is the only thread that can manipulate host views.[^iq7-1]
- The JavaScript thread runs React's render phase and layout (Yoga, in C++).[^iq7-1]
- The renderer is thread safe because it uses immutable data. Each update clones objects.[^iq7-1]
- Most renders run on the JS thread. A high-priority event on the UI thread can run the whole pipeline synchronously on the UI thread.[^iq7-2]
- The commit phase (layout and tree promotion) runs on a background thread. The mount phase (tree diffing, promotion, view mounting) runs on the UI thread. If the commit runs on the UI thread, mounting runs synchronously on it.[^iq7-3]
- A busy JS thread blocks touch handling in JS and JS animations. Native scrolling and native stack transitions keep running.[^iq7-4]

**Common wrong answer:** "There is a separate shadow thread that does layout, and the Bridge sends batched JSON between threads." That is the old model. In the New Architecture, the renderer uses immutable data, layout runs in C++ (Yoga), and the whole pipeline can run synchronously on the UI thread.[^iq7-1][^iq7-2]

**Likely follow-up:** Why does a scroll stay smooth when JS is blocked? The scroll view lives on the UI thread. Scroll events go to JS, but the scroll does not wait for them.[^iq7-4]

### Q8. How does React 19 (concurrent rendering) work in React Native? Transitions, Suspense, and automatic batching.

**Short answer (say this first, 2 to 4 sentences):** The New Architecture supports Concurrent React in full. This includes Suspense, Transitions, automatic batching, and `useLayoutEffect`.[^iq8-1] React 19 updates can be interrupted, because the renderer can hold several in-progress trees and work at several priorities.[^iq8-2] At v0.88.1 the `react` peer dependency is `^19.3.0`.[^iq8-3]

**Key points:**
- The old Bridge design could not support concurrent features. The New Renderer fixes this with multiple trees and priorities.[^iq8-2]
- The render phase is interruptible. A high-priority UI event can interrupt it.[^iq8-4]
- Transitions mark an update as low priority. `startTransition` keeps input responsive while React renders the slow update in the background. This is React behavior, not a React Native API.
- Suspense shows a fallback while a part of the tree waits. React Native docs use it to lazy load components.[^iq8-5]
- Automatic batching groups several state updates into one render. In React 18 and later this also covers timers and promises (React behavior, not checked in this repo).[^iq8-1]
- Your components must follow the Rules of React to be safe in concurrent mode. The interop layer for old modules does not support concurrent features.[^iq8-6]

**Example or code (only when it helps, max 15 lines):**
```js
// Not compiled: needs a React Native runtime.
const [isPending, startTransition] = useTransition();
const onChange = text => {
  setQuery(text); // urgent: keeps the input responsive
  startTransition(() => setResults(search(text))); // can be interrupted
};
```

**Common wrong answer:** "Concurrent rendering uses more threads, so my JS runs in parallel." Wrong. Your JavaScript still runs on one thread. Concurrent React only lets React pause and resume work and pick priorities.[^iq8-4]

**Likely follow-up:** What breaks if a component has side effects in render? React can run render more than once or drop a render. Side effects in render then run twice or leak. Keep render pure.[^iq8-6]

### Q9. How does Metro bundle an app? Cover inline requires, tree shaking status, and source maps.

**Short answer (say this first, 2 to 4 sentences):** Metro builds a dependency graph from your entry file. It transforms each file with Babel, then serializes the modules into one bundle. The default React Native Metro config turns on `inlineRequires`, so modules load lazily at first use.[^iq9-1] Metro has no tree shaking pass in the transform worker I checked (installed 0.84.3, unverified at 0.87), so unused exports stay in the bundle.[^iq9-2]

**Key points:**
- The React Native Metro config sets `inlineRequires: true` and `experimentalImportSupport: false` in `getTransformOptions`.[^iq9-1]
- Inline requires move a `require` call to the place of first use. This cuts startup work. It applies to `require` calls, not to `import` statements, in the docs.[^iq9-3]
- Expo projects do not inline requires by default. You can set `inlineRequires: true` yourself.[^iq9-3]
- The transform worker does constant folding and platform inlining. I found no tree shaking pass (unverified at 0.87).[^iq9-2]
- Source maps: on Android they are on by default in release. On iOS they are off by default and you set `SOURCEMAP_FILE`.[^iq9-4]
- Use `metro-symbolicate` with the source map to read release stack traces.[^iq9-4]

**Example or code (only when it helps, max 15 lines):**
```js
// Proof run with metro-transform-plugins (see scratch/B/proof-9.txt).
// Input:  const a = require('./a'); export function f(){ return a.x(); }
// Output: export function f() { return require('./a').x(); }
```

**Common wrong answer:** "Metro tree shakes unused code like webpack." Wrong as far as I could check (unverified at 0.87). Dead exports stay in the bundle unless a framework adds a custom step.[^iq9-2]

**Likely follow-up:** What is a pitfall of inline requires? Module side effects run later than you expect, at first use. You can block a module with `inlineRequires.blockList` or `nonInlinedRequires`.[^iq9-3]

### Q10. How do animations work? Animated with useNativeDriver, the C++ Native Animated canary, and Reanimated (worklets) at a high level.

**Short answer (say this first, 2 to 4 sentences):** With `Animated`, the default driver runs on the JS thread and sends new values each frame. With `useNativeDriver: true`, JS sends the animation graph to native once. Then native runs it on the UI thread, so a busy JS thread cannot drop frames. The C++ Native Animated option is a feature flag in canary stage. Reanimated runs worklets on the UI thread (general knowledge, not from this repo).

**Key points:**
- `useNativeDriver` is required. If you omit it, `Animated` logs a warning that you must set it to `true` or `false`.[^iq10-1]
- The native driver cannot animate every prop. It supports non-layout props such as transform and opacity.[^iq10-2]
- The flag `cxxNativeAnimatedEnabled` uses a C++ implementation of Native Animated. Its default is `false` and its release stage is `canary`.[^iq10-3]
- `useSharedAnimatedBackend` is an experimental flag, default `false`. It is what makes every prop drivable natively.[^iq10-4]
- `animatedForceNativeDriver` forces the native driver for all animations, but only when `cxxNativeAnimatedEnabled` and `useSharedAnimatedBackend` are also on.[^iq10-1]
- A value can use only one driver. If one animation on a value uses the native driver, all must.[^iq10-2]
- Reanimated worklets are small JavaScript functions that run on the UI thread. Reanimated is a separate library (unverified here, no source in this repo).

**Example or code (only when it helps, max 15 lines):**
```js
// Not compiled: needs a React Native runtime.
Animated.timing(opacity, {
  toValue: 1,
  duration: 300,
  useNativeDriver: true, // required
}).start();
```

**Common wrong answer:** "Set `useNativeDriver: true` on everything." Wrong. It fails for props the native driver cannot handle, such as layout props like `width`. Use it for transform and opacity.[^iq10-2]

**Likely follow-up:** When do you pick Reanimated over Animated? Pick it for gesture-driven animation that must run fully on the UI thread, with shared values and worklets.

## Part 3: UI and performance

### Q11. ScrollView vs FlatList vs SectionList vs FlashList: how does virtualization work, and which props matter?

**Short answer (say this first, 2 to 4 sentences):** ScrollView renders all its children at once. FlatList and SectionList sit on VirtualizedList, which renders only a window of items around the viewport and drops the rest. FlashList is a third-party list library built for performance. Use ScrollView for short, bounded content and a virtualized list for long data.[^iq11-1][^iq11-2]

**Key points:**
- ScrollView mounts every child, so long data costs memory and startup time.[^iq11-1]
- VirtualizedList defaults: `windowSize` 21 (10 viewports above, 10 below, 1 visible), `initialNumToRender` 10, `maxToRenderPerBatch` 10, `updateCellsBatchingPeriod` 50 ms.[^iq11-3][^iq11-4]
- `getItemLayout` skips measurement when the item size is fixed. `keyExtractor` sets the React keys from your data, for example from `id`.[^iq11-5]
- `removeClippedSubviews` defaults to `true` only on Android. The flag `shouldUseRemoveClippedSubviewsAsDefaultOnIOS` is `false` by default at HEAD.[^iq11-6][^iq11-7]
- A bigger `windowSize` means less blank space but more memory. A smaller one means the reverse.[^iq11-8]
- SectionList is a wrapper over VirtualizedList. Its section headers stick on iOS by default (`stickySectionHeadersEnabled` is `Platform.OS === 'ios'`).[^iq11-10][^iq11-9]
- FlatList and SectionList are `PureComponent`. If `renderItem` reads state that is not in `data`, pass it as `extraData`, or the list does not re-render.[^iq11-11]
- The docs name FlashList and Legend List as third-party options.[^iq11-2]

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled: needs a React Native runtime
<FlatList
  data={items}
  keyExtractor={item => item.id}
  getItemLayout={(_, i) => ({length: 64, offset: 64 * i, index: i})}
  windowSize={7}
  renderItem={({item}) => <Row item={item} />}
/>
```

**Common wrong answer:** "Use FlatList for everything." A short, bounded list is simpler and often faster in a ScrollView. Very large or complex lists may need FlashList or Legend List.

**Likely follow-up:** Why do you see blank areas on fast scroll? Items outside the render window are not mounted yet, so the render rate falls behind the scroll speed. Raise `windowSize` or `maxToRenderPerBatch`, or make rows cheaper.

### Q12. How do you find and fix unnecessary re-renders? memo, useCallback, useMemo, and the React Compiler.

**Short answer (say this first, 2 to 4 sentences):** First I measure with the React Profiler in React Native DevTools to see which components render and why. Then I fix the cause: move state down, keep props stable, and use `memo`, `useMemo`, and `useCallback` where the profile shows a cost. The React Compiler can add this memoization automatically. The compiler is not part of the core repo. The app adds it. The docs and the DevTools frontend mention it.[^iq12-1][^iq12-2]

**Key points:**
- React Native DevTools includes the React Components and Profiler panels. The Profiler records component render timing and React commits.[^iq12-1]
- `React.memo` skips a render when props are equal. A custom compare function can be the second argument.[^iq12-3]
- Memoization only helps when props are stable. A new inline function or object each render breaks it.
- The React Compiler is a build-time Babel tool that memoizes automatically. The 0.78 release post says you install only the compiler package and add the Babel plugin.[^iq12-4]
- Source proof: a grep for `react-compiler` and `babel-plugin-react-compiler` in the repo (outside `node_modules`, `tmp`, `.git`) finds 0 files. `node_modules` has `hermes-compiler` only.[^iq12-5]
- The DevTools docs say compiler-optimized components show a "Memo ✨" badge. The bundled DevTools frontend has the tooltip "This component has been auto-memoized by the React Compiler."[^iq12-6]
- The compiler is opt-in per app. Core RN does not enable it by default.[^iq12-5]

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled: needs a React Native runtime
const Row = memo(
  function Row({title}) { return <Text>{title}</Text>; },
  (prev, next) => prev.title === next.title,
);
```

**Common wrong answer:** "Wrap everything in useMemo and useCallback." That adds cost and noise without a profile. Also wrong: "React Native ships the React Compiler." The repo has no compiler. The app adds the Babel plugin.

**Likely follow-up:** Does the compiler remove the need for `memo`? In most components yes, because it memoizes for you. Manual hooks stay useful for code the compiler skips.

### Q13. How does layout work? Yoga, flexbox defaults that differ from the web, and the gap and percentage rules.

**Short answer (say this first, 2 to 4 sentences):** Yoga is the C++ layout engine. It computes flexbox layout in the native shadow tree, not in JS. The defaults differ from the web: `flexDirection` is `column`, `alignContent` is `flex-start`, and `flexShrink` is `0`. `gap`, `rowGap`, and `columnGap` work like CSS, and percentage values are supported on the New Architecture.[^iq13-1][^iq13-2]

**Key points:**
- Yoga source defaults: `flexDirection` `Column`, `alignContent` `FlexStart`, `alignItems` `Stretch`, `flexWrap` `NoWrap`, `boxSizing` `BorderBox`.[^iq13-3]
- `flexShrink` is `0` by default. The web value `1` is used only when Yoga `useWebDefaults` is on, and that is off by default in the Yoga `Config`.[^iq13-4]
- The `flex` prop accepts a single number.[^iq13-1]
- `gap` is a shorthand for `rowGap` and `columnGap`. Gap goes between children, not at the edges.[^iq13-5]
- Gap and layout values accept points or percentage strings such as `'10%'`. Percentages need a parent with a defined size.[^iq13-6][^iq13-7]
- Fabric builds a Yoga node per shadow node and sets Yoga style from props.[^iq13-8]

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled: needs a React Native runtime
const styles = StyleSheet.create({
  row: {flexDirection: 'row', gap: 8, flexWrap: 'wrap'},
  half: {width: '50%'}, // parent needs a defined width
});
```

**Common wrong answer:** "Layout runs on the JS thread." Yoga runs in native C++ in the shadow tree. Another wrong answer: "Defaults match the web." Three defaults differ.

**Likely follow-up:** Why does my `width: '50%'` give zero? The parent has no defined size. Percentages resolve against the parent.

### Q14. How do you write platform-specific code and styles? Platform.select, .ios/.android files, and the native-only file resolution in Metro.

**Short answer (say this first, 2 to 4 sentences):** Use `Platform.OS` for small branches and `Platform.select` for values. Use `.ios.js` and `.android.js` files for larger differences. Use `.native.js` for code shared by iOS and Android but not the web. Metro tries the platform extension first, then `.native`, then the plain file.[^iq14-1][^iq14-2]

**Key points:**
- `Platform.select` takes the keys `ios`, `android`, `native`, and `default`.[^iq14-1]
- On iOS the lookup is: `ios`, then `native`, then `default`. On Android it is: `android`, then `native`, then `default`.[^iq14-3]
- Metro resolver order for `file`: `file.<platform>.js`, then `file.native.js` (when `preferNativePlatform` is set), then `file.js`.[^iq14-2]
- Metro config default platforms are `['android', 'ios']`.[^iq14-4]
- The docs advise configuring the web bundler to ignore `.native.js` files.[^iq14-1]
- Platform file resolution happens at bundle time, so the other platform file is not in the bundle.
- Metro inlines `Platform.OS` and `Platform.select` per target platform (`inlinePlatform: true`). Constant folding drops dead branches only when `dev` is off.[^iq14-5]

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled: needs a React Native runtime
const shadow = Platform.select({
  ios: {shadowOpacity: 0.2},
  android: {elevation: 4},
  default: {},
});
// Button.ios.js, Button.android.js, import './Button'
```

**Common wrong answer:** "`Platform.OS` checks always keep both branches in the bundle." Metro runs an inline-platform Babel step that replaces `Platform.OS` and `Platform.select` with the target platform value. In a non-dev build, constant folding then removes the dead branch. Still, a platform file is the clearer choice for large differences, because the other platform's code is never parsed.[^iq14-5]

**Likely follow-up:** When does `.native.js` win over `.js`? When Metro bundles for a native platform and no `.ios.js` or `.android.js` file exists.

### Q15. How do you profile and debug performance? React Native DevTools, Perf Monitor, Hermes sampling profiler, and the React Profiler.

**Short answer (say this first, 2 to 4 sentences):** I profile a release-like build with Development Mode off. I use React Native DevTools for JS: the Performance panel (since 0.83), the React Profiler, and the Memory panel. I use the Perf Monitor for a quick view of JS and UI frame rates. For native jank I use Android Studio system tracing or Xcode Instruments.[^iq15-1][^iq15-2]

**Key points:**
- Dev mode is slow. Always measure with `dev` off.[^iq15-3]
- The Perf Monitor shows two frame rates (JS and UI). Open it from the Dev Menu.[^iq15-4]
- The DevTools Performance panel (since 0.83) shows JS execution, React Performance tracks, Network events, and User Timings in one timeline.[^iq15-1]
- The React Profiler panel records component render timing and commits. The Memory panel takes heap snapshots.[^iq15-5][^iq15-6]
- The standalone `systrace` tool is removed. Use the Android Studio Profiler.[^iq15-2]
- `PerformanceObserver` and `performance` APIs give runtime telemetry.[^iq15-1]
- A separate Hermes sampling profiler doc page is not in the checked docs (unverified). The DevTools Performance panel is the current JS profiling path.

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled: needs a React Native runtime
performance.mark('list-start');
// ... work ...
performance.measure('list', 'list-start'); // shows in the Performance panel
```

**Common wrong answer:** "Profile in dev mode with the debugger attached." Dev mode adds overhead and gives false numbers. Profile a release or profileable build.

**Likely follow-up:** JS FPS is fine but the UI drops frames. What now? The cost is native, so I trace with Android Studio system tracing or Instruments.

## Part 4: Native code and ecosystem

### Q16. How do you write a TurboModule end to end (spec, codegen, native implementation, JS call)?

**Short answer (say this first, 2 to 4 sentences):** I write a typed JS spec file that extends `TurboModule`. Codegen reads that spec at build time and generates native interfaces (C++, Objective-C++, Java). I implement the generated interface in Objective-C++ and Kotlin or Java, then register the module. In JS I call it through `TurboModuleRegistry`, with synchronous or Promise-returning methods.[^iq16-1][^iq16-2]

**Key points:**
- The spec is a `Native<Name>.ts` or `.js` file. It exports `interface Spec extends TurboModule` and a default export from `TurboModuleRegistry.get<Spec>('Name')` or `getEnforcing<Spec>('Name')`.[^iq16-1][^iq16-3]
- `getEnforcing` throws an invariant error when the native module is missing. `get` returns `null`.[^iq16-3]
- You tell Codegen where the specs are in the app or library `package.json`, under `codegenConfig`: `name`, `type` (`modules`, `components` or `all`), `jsSrcsDir`, and `android.javaPackageName`.[^iq16-2][^iq16-4]
- Android: your class extends the generated `<Name>Spec` and a `BaseReactPackage` registers it. iOS: your Objective-C++ class conforms to the generated `<Name>Spec` protocol. The iOS build needs `pod install` to run Codegen.[^iq16-5]
- In 0.88 there is no old Bridge module path to fall back to. `TurboCxxModule`, `RCTCxxModule` and the CxxModule support were removed, so pure C++ modules use the TurboModule C++ API.[^iq16-6]

**Example or code (only when it helps, max 15 lines):**
```ts
// specs/NativeLocalStorage.ts  (not compiled here, shape from the official docs)
import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';

export interface Spec extends TurboModule {
  setItem(value: string, key: string): void;
  getItem(key: string): string | null;
}
export default TurboModuleRegistry.getEnforcing<Spec>('NativeLocalStorage');
// package.json: "codegenConfig": {"name": "NativeLocalStorageSpec",
//   "type": "modules", "jsSrcsDir": "specs",
//   "android": {"javaPackageName": "com.nativelocalstorage"}}
```

**Common wrong answer:** "A native module sends JSON over the async bridge, so I register it with `NativeModules`." This is outdated. Modules no longer use the async Bridge in 0.88. `NativeModules` only reaches legacy modules through the interop layer. A TurboModule is a typed JSI host object, and Codegen produces the glue.[^iq16-6][^iq16-7]

**Likely follow-up:** Can a method return a value synchronously? Yes. A spec method with a plain return type is synchronous over JSI, and a `Promise<T>` return makes it async. Use synchronous calls only for cheap work.[^iq16-1][^iq16-8]

---

### Q17. How do you write a Fabric native component, and how are props, commands, and events passed?

**Short answer (say this first, 2 to 4 sentences):** I write a JS spec with `codegenNativeComponent<NativeProps>('Name')`. `NativeProps` lists props and event handlers. Commands come from `codegenNativeCommands`. Codegen builds the C++ Props, State and EventEmitter classes and the Android ViewManager interface and delegate. I then write the native view: an `RCTViewComponentView` subclass on iOS, and a `SimpleViewManager` on Android.[^iq17-1][^iq17-2][^iq17-3]

**Key points:**
- Props: `NativeProps` extends `ViewProps`. Codegen types such as `CodegenTypes.Float`, `Int32` and `Double` map to native types.[^iq17-1]
- Events: a prop typed `CodegenTypes.BubblingEventHandler<T>` (or `DirectEventHandler<T>`) is a typed event. The native side emits it. On iOS you call `self.eventEmitter.onX(...)`. On Android you dispatch through the `eventDispatcher`.[^iq17-1][^iq17-3][^iq17-4]
- Commands: you export `Commands = codegenNativeCommands<NativeCommands>({supportedCommands: [...]})`. JS calls `Commands.reload(ref)`. The first argument is always the view ref.[^iq17-1][^iq17-5]
- iOS maps the component name to the class through `codegenConfig.ios.componentProvider`. Android registers the manager in a `BaseReactPackage`.[^iq17-6][^iq17-7]
- Without `ios.componentProvider`, Codegen tries to find the class by crawling `.mm` files and logs a deprecation warning.[^iq17-9]
- Props update on iOS in `updateProps:oldProps:`. You compare old and new props and call `[super updateProps:...]` last.[^iq17-3]

**Example or code (only when it helps, max 15 lines):**
```ts
// specs/WebViewNativeComponent.ts (not compiled here)
import type {CodegenTypes, HostComponent, ViewProps} from 'react-native';
import {codegenNativeCommands, codegenNativeComponent} from 'react-native';

export interface NativeProps extends ViewProps {
  sourceURL?: string;
  onScriptLoaded?: CodegenTypes.BubblingEventHandler<{result: 'success' | 'error'}> | null;
}
interface NativeCommands { reload: (ref: React.ElementRef<HostComponent<NativeProps>>) => void }
export const Commands = codegenNativeCommands<NativeCommands>({supportedCommands: ['reload']});
export default codegenNativeComponent<NativeProps>('CustomWebView') as HostComponent<NativeProps>;
```

**Common wrong answer:** "Use `requireNativeComponent` and a `RCTViewManager` with `RCT_EXPORT_VIEW_PROPERTY`." That is the legacy way. It still loads through an interop layer, but new code uses a Codegen spec.[^iq17-8]

**Likely follow-up:** Why is the view ref the first argument of a command? Because Fabric dispatches the command to the native view for that shadow node, so JS must pass the host component instance.[^iq17-5]

---

### Q18. Expo vs bare React Native CLI: what are the real differences in 2026 (prebuild, dev builds, EAS, config plugins)?

**Short answer (say this first, 2 to 4 sentences):** Both build the same React Native app. The difference is who owns the native folders. With Expo and Continuous Native Generation (CNG), `npx expo prebuild` generates `android/` and `ios/` from a template, `app.json` and config plugins. With a bare app, you commit and edit those folders by hand. Expo says "managed vs bare" is deprecated. Expo SDK packages and EAS work in both.[^iq18-1][^iq18-2]

**Key points (facts from external Expo docs, not from this repo):**
- Prebuild is optional. If `android/` and `ios/` exist, EAS Build does not run prebuild. If they are absent, EAS Build runs it.[^iq18-1]
- Config plugins are functions that change native projects during prebuild. They replace hand edits of `Info.plist` or `AndroidManifest.xml`. `prebuild --clean` deletes and recreates the native folders.[^iq18-1]
- A development build is your own app with `expo-dev-client`. You need one when you use native code that Expo Go does not contain. Build it with `npx expo run:ios|android` (local) or `eas build --profile development` (cloud, or `--local`).[^iq18-3]
- Rebuild the native app after you add a native library, change app config, or upgrade the SDK. JS-only changes need only `npx expo start`.[^iq18-3]
- Expo SDK 58 targets React Native 0.88 and React 19.3.0, with Node 22.13 or newer. Each SDK targets one RN version.[^iq18-4]
- Facts from this repo: a bare app has `newArchEnabled=true` in `gradle.properties` and no opt-out, so the New Architecture rule is the same in both.[^iq18-5][^iq18-6]

**Example or code (only when it helps, max 15 lines):**
```sh
# Expo, external docs. Not run here.
npx expo install expo-dev-client
npx expo prebuild --clean
npx expo run:ios
eas build --platform ios --profile development
```

**Common wrong answer:** "Expo is a limited sandbox, and you must eject to use native code." This is outdated. Expo calls ejecting deprecated. You add native code with modules and config plugins, and the Expo SDK works in any RN app.[^iq18-1][^iq18-2]

**Likely follow-up:** When do you pick bare? When you must hand-maintain native projects, such as a brownfield app. Expo says CNG is not meant for existing brownfield projects.[^iq18-1]

---

### Q19. How do you handle navigation, deep links, and app state in a production app? (React Navigation native stack, linking config, AppState)

**Short answer (say this first, 2 to 4 sentences):** I use React Navigation with the native stack, which uses `UINavigationController` on iOS and `Fragment` on Android. I pass a `linking` config with `prefixes` and a `config` map from URL paths to screens, and I register the scheme or universal link on each platform. For app state I use `AppState` (`active`, `background`, `inactive`) and subscribe in an effect, then remove the subscription on cleanup.[^iq19-1][^iq19-2][^iq19-3]

**Key points (React Navigation facts are from external docs, current page is 7.x):**
- Native stack: platform APIs handle animation and gestures. It is a good default, but it supports fewer custom behaviors than the JS stack. Bugs belong in `react-native-screens`.[^iq19-1]
- Deep links have two cases: cold start (set the initial state) and warm (update state). The `linking` prop handles both. Do not drive links through a `ref`.[^iq19-2]
- Setup: Android needs an `intent-filter` with `VIEW`, `launchMode="singleTask"` and `autoVerify="true"` for App Links. iOS needs the URL scheme, and Associated Domains for universal links.[^iq19-2]
- For push notifications, override `getInitialURL` and `subscribe` in the `linking` object.[^iq19-2]
- Core RN `Linking` has `getInitialURL()`, `addEventListener('url', ...)`, `openURL` and `canOpenURL`.[^iq19-4]
- `AppState.addEventListener` accepts `'change'`, `'focus'`, `'blur'` and `'memoryWarning'`. The status type is `'inactive' | 'background' | 'active' | 'extension' | 'unknown'`. `focus` and `blur` are Android-only (AppState docs, appstate.md:94,98).[^iq19-5]

**Example or code (only when it helps, max 15 lines):**
```js
// not compiled here
useEffect(() => {
  const sub = AppState.addEventListener('change', (state) => {
    if (state === 'active') refreshSession();
  });
  return () => sub.remove();
}, []);
```

**Common wrong answer:** "Read `AppState.currentState` once on mount and assume it stays current." The value changes. Subscribe to `'change'` and clean up. Also, a deep link on a cold start arrives through `getInitialURL`, not through the `url` event.[^iq19-4][^iq19-5]

**Likely follow-up:** How do you test a deep link? Use `xcrun simctl openurl booted "example://chat/jane"` on iOS or `adb shell am start -W -a android.intent.action.VIEW -d "example://chat/jane" <package>` on Android.[^iq19-2]

---

### Q20. How do you upgrade a React Native app and its libraries to a new version (0.81 to 0.88)? Cover the upgrade helper, library compatibility, the interop layer, and breaking removals.

**Short answer (say this first, 2 to 4 sentences):** I upgrade one minor at a time, or jump with a diff. I open the Upgrade Helper, pick the from and to versions, then update `package.json` and the native template files. Then I check every native library for New Architecture support, because 0.82 removed the opt-out. I read the Breaking sections of the changelog for each version in between. With Expo, I bump the SDK, run `npx expo install --fix`, and re-run prebuild.[^iq20-1][^iq20-2][^iq20-3]

**Key points:**
- The Upgrade Helper shows a diff of the template between two versions: `package.json`, then the other generated files.[^iq20-1]
- 0.82: no opt-out of the New Architecture on Android (`newArchEnabled=false`) or on iOS. A library that only works on the old architecture must be replaced or updated first.[^iq20-3]
- 0.84: Hermes V1 is the default engine. Legacy-architecture iOS code is no longer included by default. `unstable_shouldEnableLegacyModuleInterop()` was removed, and the CxxModule family was removed.[^iq20-4]
- 0.85: the Jest preset moved to the `react-native/jest-preset` package. Support for EOL Node.js lines was dropped.[^iq20-5]
- 0.87: Node 22.13 or newer. The default JS API is the Strict TypeScript API (opt out with `customConditions: ["react-native-legacy-deep-imports"]`). AGP 9 on Android. Deep imports of `react-native/src/private/...` lose types.[^iq20-6]
- The interop layers (legacy view managers and legacy modules) still exist, but 0.87 put them behind `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` and `RCT_REMOVE_LEGACY_MODULE_INTEROP` so an app can compile them out. Treat the interop layer as a bridge for old libraries, not a destination.[^iq20-7]

**Example or code (only when it helps, max 15 lines):**
```sh
# bare app, not run here
yarn add react-native@0.88 react@<version from Upgrade Helper>
# then apply the template diff from the Upgrade Helper
# Expo app, external docs
npx expo install expo@^58 --fix   # (check the SDK 58 upgrade guide)
npx expo prebuild --clean
```

**Common wrong answer:** "Set `newArchEnabled=false` until libraries catch up." This does not work from 0.82. The flag opt-out was removed.[^iq20-3]

**Likely follow-up:** How do you find incompatible libraries before you upgrade? Check each library's release notes for New Architecture support, run a test build on a branch, and use the interop layer only as a short-term fix.[^iq20-1][^iq20-7]

---

## Part 5: Testing

### Q21. How do you structure a test strategy for a React Native app? Pyramid or trophy, and what runs where?

**Short answer (say this first, 2 to 4 sentences):** I use static checks as the base, then many Jest component and integration tests, then a few end-to-end flows on a real build. The pyramid says "many unit tests". The trophy says "most tests at the integration level". For a mobile app I prefer the trophy, because most bugs sit where components, state, and the network meet. Both models are opinions, not rules.[^iq21-1]

**Key points:**
- Static layer: TypeScript and ESLint. It runs in seconds on Linux.[^iq21-1]
- Unit and component layer: Jest with the React Native preset and React Native Testing Library. It runs in Node, with no device. Layout does not run there.[^iq21-2][^iq21-3]
- End-to-end layer: Maestro, Detox, or Appium on a simulator or emulator. It is slow and costly, so I cover only the critical journeys.[^iq21-1]
- Order CI jobs from cheap to costly: lint and types, then Jest, then build, then E2E smoke, then a release gate.[^iq21-4]
- The React Native repo tests itself in three layers: Jest in `__tests__` folders, Fantom (`*-itest.js`) for engine internals, and the RNTester app. Fantom is for React Native contributors, not for app teams.[^iq21-5]

**Example or code (only when it helps, max 15 lines):**
```sh
# Local order of checks (not run as one script)
yarn tsc --noEmit
yarn eslint . --max-warnings 0
yarn jest --ci
maestro test .maestro/smoke.yaml   # needs a device, not run here
```

**Common wrong answer:** "Write E2E tests for everything, because they test the real app." E2E tests are slow and flaky. A broad E2E suite makes CI slow and teams stop trusting it.

**Likely follow-up:** Can you use Fantom for your app tests? No. Its README marks it as experimental, limited to React Native internals, and it lives in `private/` in the repo.[^iq21-5]

---

### Q22. How do you unit and component test with Jest and React Native Testing Library, and how do you mock native modules and TurboModules?

**Short answer (say this first, 2 to 4 sentences):** I use Jest with the preset `@react-native/jest-preset`. I render the screen with React Native Testing Library (RNTL), query it like a user (role, label, text), and use `userEvent`. Jest has no native side, so I replace native modules: `jest.spyOn` for one call, `jest.mock` in a setup file for a library. For a TurboModule I mock the registry lookup or the spec file.[^iq22-1][^iq22-2][^iq22-3]

**Key points:**
- The preset moved. In 0.84 `react-native` still shipped `jest-preset.js` and a `jest/` folder. In 0.85 the file is a stub that requires `@react-native/jest-preset` and throws a migration message if it is missing. In 0.87 the stub is gone from the tarball.[^iq22-1][^iq22-2]
- Migration: install `@react-native/jest-preset` as a dev dependency and set `module.exports = {preset: '@react-native/jest-preset'};`. The package needs Node 22.13 or newer.[^iq22-2][^iq22-3]
- RNTL 14.1.0 needs React 19, React Native 0.78 or newer, and the `test-renderer` package. `render` and the event helpers return Promises, so I `await` them.[^iq22-4]
- RNTL query order: `getByRole`, `getByLabelText`, `getByPlaceholderText`, `getByText`, and `getByTestId` last. Use `queryBy*` for absence and `findBy*` to wait.
- The built-in matchers such as `toBeOnTheScreen` replace `@testing-library/jest-native`, which npm marks as no longer maintained.[^iq22-5]
- With the New Architecture, a module read through `TurboModuleRegistry.get` needs a mock of the registry or of the spec file. Setting `NativeModules.Foo` only works for code that reads `NativeModules`.[^iq22-6]

**Example or code (only when it helps, max 15 lines):**
```js
// Run: yes. Jest 30.5.2, RNTL 14.1.0, RN 0.88.1. 3 tests passed.
test('shares a greeting', async () => {
  const spy = jest.spyOn(Share, 'share').mockResolvedValue({action: 'sharedAction'});
  const user = userEvent.setup();
  await render(<Greeter />);
  await user.type(screen.getByPlaceholderText('Name'), 'Ana');
  await user.press(screen.getByRole('button', {name: 'Share'}));
  expect(spy).toHaveBeenCalledWith({message: 'Hello Ana'});
  expect(await screen.findByText('Shared for Ana')).toBeOnTheScreen();
});
test('mock a TurboModule lookup', () => {
  jest.spyOn(TurboModuleRegistry, 'get').mockReturnValue({ping: () => 'pong'});
  expect(TurboModuleRegistry.get('MyModule').ping()).toBe('pong');
});
```

**Common wrong answer:** "Set `preset: 'react-native'` in `jest.config.js`." That value was correct before 0.85. In 0.88 it fails, because the `react-native` package no longer ships the preset.[^iq22-1][^iq22-2]

**Likely follow-up:** How do you test an animation? Use `jest.useFakeTimers()` and `jest.advanceTimersByTime(ms)`. With `useNativeDriver: false` the callback gets `{finished: true}`. A native-driver animation runs on the UI thread, so Jest cannot see it.[^iq22-6]

---

### Q23. Detox vs Maestro vs Appium: how do you choose for a team in 2026, and what causes flaky E2E tests?

**Short answer (say this first, 2 to 4 sentences):** For most React Native teams I start with Maestro. It is black box, uses YAML, and needs no code in the app. I pick Detox when I need in-process synchronization and I accept the version risk. I pick Appium when I need other languages or a WebDriver-only device cloud. Flakiness comes from animations, fixed sleeps, network, shared state, and version drift.[^iq23-1][^iq23-2][^iq23-3]

**Key points:**
- Maestro 2.12.0 reads the screen through the accessibility tree and installs a small driver on the device. It can also control things outside the app, such as permission dialogs.[^iq23-1]
- Detox 20.51.4 is gray box. It waits until the app is idle (network, main thread, timers, animations, JS thread). An endless animation or a polling timer keeps the app "busy" and the test hangs.[^iq23-2]
- Detox README states full New Architecture compatibility for RN 0.77 to 0.84. I found no proof for RN 0.88, and an open issue reports a failure on RN 0.85.3 with the New Architecture. So I run a spike on my exact RN version first.[^iq23-2]
- Appium 3.9.0 is black box and has no app synchronization. I add explicit waits. It fits other languages and most device clouds.[^iq23-3]
- Both Detox `by.id` and Maestro `id:` match the `testID` prop. On Android, RN exposes `testID` as the `resource-id`.[^iq23-4]
- Flake fixes: wait on a visible state, reset app data per test (`clearState` in Maestro, `newInstance: true` in Detox), mock the server, pin the RN version and the OS image, and test a release-like build in CI.[^iq23-5]

**Example or code (only when it helps, max 15 lines):**
```yaml
# flows/smoke.yaml. Not run (no Maestro CLI here). Same syntax as the checked flows in the testing chapter.
appId: com.example.app
onFlowStart:
  - clearState
---
- launchApp
- tapOn:
    id: "login-button"
- assertVisible:
    id: "home-title"
```

**Common wrong answer:** "Detox is always best, because it is gray box and faster." It depends on private React Native internals, so each RN minor can break it. The Detox team documents support only up to RN 0.84.[^iq23-2]

**Likely follow-up:** How do you find a flaky test? Re-run the failed test once in CI, track the tests that pass on a re-run, and fix or delete them.[^iq23-5]

---

### Q24. Why is snapshot testing criticized, and what do you use instead? What about `react-test-renderer` in React 19?

**Short answer (say this first, 2 to 4 sentences):** Snapshot tests store a rendered tree and compare it on each run. Snapshots are large, nobody reads the diffs, people update them without review, and they test structure, not behavior. I use RNTL queries and matchers for behavior, and small inline snapshots only for tiny, stable output. React 19 deprecates `react-test-renderer`, so I do not start new tests on it.[^iq24-1][^iq24-2]

**Key points:**
- The criticism is an opinion shared by the Testing Library guidance. It is not a measured result.[^iq24-1]
- Replace a tree snapshot with an assertion on what the user sees: `expect(await screen.findByText('Shared for Ana')).toBeOnTheScreen()`.
- A small inline snapshot (an error object or a style) is fine. Jest wrote and matched one in my run.[^iq24-3]
- React 19 prints a warning when you call `ReactTestRenderer.create()`. React says the package stays on npm, is not maintained, and may break with new React features.[^iq24-2]
- npm does not flag `react-test-renderer@19.3.1` as deprecated. The deprecation is a React runtime warning.[^iq24-4]
- RNTL 14 replaced `react-test-renderer` with the `test-renderer` package, and lists `test-renderer ^1.0.0` as a peer dependency.[^iq24-5]

**Example or code (only when it helps, max 15 lines):**
```js
// Run: yes. Jest 30.5.2. 1 snapshot passed.
test('inline snapshot is small', () => {
  expect({ok: true}).toMatchInlineSnapshot(`
    {
      "ok": true,
    }
  `);
});
```

**Common wrong answer:** "Snapshot tests give full coverage, so we do not need other tests." A snapshot only proves that the output did not change. It does not prove the output is right.

**Likely follow-up:** What do you do with old `react-test-renderer` tests? Migrate to RNTL. The old package still installs (19.3.1), but React does not maintain it.[^iq24-2][^iq24-4]

---

### Q25. How do you set up CI for a React Native app? Cover jobs, caching, emulator and simulator, device clouds, and release gates.

**Short answer (say this first, 2 to 4 sentences):** I order jobs from cheap to costly and stop early on failure. Lint, types, and Jest run on Linux. Then a release build. Then a small E2E smoke set on an Android emulator (Linux with KVM) or an iOS simulator (macOS). A last job is the release gate with manual approval. I run the full E2E suite nightly or on a device cloud.[^iq25-1][^iq25-2]

**Key points:**
- macOS runners cost the most. GitHub lists standard macOS at 0.062 USD per minute and Linux 2 core at 0.006 USD per minute, about ten times more. So only the iOS build and simulator tests use macOS.[^iq25-3]
- Android emulators run on Linux runners with KVM. The emulator action runs each line of `script` as a separate shell command, so `export PATH` on one line does not carry over.[^iq25-4]
- Cache the package manager through `actions/setup-node` (`cache: yarn`). Also cache Gradle and CocoaPods. I did not measure the cache gains.[^iq25-2]
- Use `concurrency` with `cancel-in-progress: true` to stop old runs on the same ref.[^iq25-2]
- Device clouds (BrowserStack, Sauce Labs, AWS Device Farm, Firebase Test Lab, Maestro Cloud) give real devices and parallel runs. Prices change, so check the vendor page before you quote one.[^iq25-6]
- For Expo apps, EAS Workflows can run a `build` job and then a `maestro` job with `build_id` and `flow_path`.[^iq25-7]

**Example or code (only when it helps, max 15 lines):**
```yaml
# Reduced from the testing chapter sample. Parsed with PyYAML (2 jobs). Not run on GitHub.
jobs:
  static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with: {node-version: 22, cache: yarn}
      - run: yarn install --frozen-lockfile
      - run: yarn tsc --noEmit
      - run: yarn jest --ci --coverage
  release-gate:
    needs: [static]
    runs-on: ubuntu-latest
    environment: production
```

**Common wrong answer:** "Run the whole E2E suite on every pull request, on macOS." It is slow and costly. Run a small smoke set on each pull request and the full suite on a schedule.[^iq25-3]

**Likely follow-up:** How does the release gate work? A job with `environment: production` waits for manual approval, then a later step runs the store upload (for example EAS or Fastlane).[^iq25-1]

---

### Q26. How do coding agents and MCP servers change mobile testing, and what must stay deterministic?

**Short answer (say this first, 2 to 4 sentences):** Agents change who writes and runs tests. They do not change what a good test is. An MCP server gives an agent a screenshot, a view tree, input, and logs from a simulator, so the agent can explore a screen and draft a test. The CI gate must stay plain code: fixed Jest tests, fixed Maestro or Detox files, a fixed build, and seeded data. A human owns the oracle, the rule for what "right" means.[^iq26-1][^iq26-2]

**Key points:**
- Servers I checked on 2026-10-29: `@mobilenext/mobile-mcp` 1.0.14, `appium-mcp` 1.99.1, and the Maestro CLI MCP (`maestro mcp`, CLI 2.12.0). Expo MCP needs an Expo project.[^iq26-1]
- The agent can read the accessibility tree (cheap, exact labels, stable refs) or a screenshot (shows layout, costs more tokens). Use the tree first.[^iq26-2]
- Good `testID` and `accessibilityLabel` values matter more now. Without names, the agent guesses with pixel coordinates, and coordinates break when the layout changes.[^iq26-3]
- Maestro `assertWithAI` is experimental. `optional` is `true` by default, so a failed AI check does not stop the run. Do not put it in the gate.[^iq26-4]
- Risks: secrets in screenshots, prompt injection through app text, and an agent that writes a test that always passes. Use fake accounts and a test backend.[^iq26-2]
- `appium-mcp` says to use it only as a local single-user server or a trusted CI job. Do not build `remoteServerUrl` from pull request content.[^iq26-2]

**Example or code (only when it helps, max 15 lines):**
```sh
# Connect the Maestro MCP server to a coding agent (not run here)
claude mcp add maestro -- maestro mcp
```

**Common wrong answer:** "The agent decides pass or fail in CI, so we do not need fixed tests." The same prompt can take a different path on each run. CI must replay fixed scripts. Agents draft and explore outside the gate.[^iq26-2]

**Likely follow-up:** Where do agents help most? Drafting Jest and RNTL tests, exploring a new screen, saving a working Maestro flow, and triaging a failure. A human reviews each file as code.[^iq26-2]

---

### Q27. Would you use an AI-native testing service such as Autosana for a mobile app, and what would you check first?

**Short answer (say this first, 2 to 4 sentences):** I would try it on non-gate flows first. These services run an agent that follows plain-language steps on cloud devices. They help most with hard flows such as OTP and push. I would check the oracle first. I would plant a known bug and see if the flow fails.[^iq27-1]

**Key points:**
- Autosana tests are natural-language flows. They can live as `*.flow.yaml` files in the repo.[^iq27-1]
- An iOS upload must be a simulator `.app`. A React Native app must be a Release build. Expo uses an EAS profile with `simulator: true`.[^iq27-2]
- Pricing is per AI action ($0.10, or $0.01 when cached) plus monthly plans. This is a vendor page checked on 2026-10-29.[^iq27-3]
- The vendor says it replays cached steps and self-heals. These are vendor claims. I found no independent measurement.[^iq27-1]
- Check data handling. The build and the screenshots go to the vendor cloud. I found no public retention policy.[^iq27-4]

**Example or code (only when it helps, max 15 lines):**
```yaml
# A flow file in .autosana/ (not run here, schema from the vendor docs)
name: Login
instructions: |
  Sign in as the test user.
  Verify the home screen shows the user email.
```

**Common wrong answer:** "AI testing removes flaky tests." The agent can take a different path each run, and self-healing can hide a real bug. A person must still write the expected result.[^iq27-5]

**Likely follow-up:** Would it replace Maestro in CI? Not for the gate. A fixed Maestro file is free, versioned, and repeatable. The service is a layer for hard flows and pull request video.[^iq27-5]

---

## Footnotes

[^iq1-1]: packages/react-native/package.json (version field, RN main) and CHANGELOG.md:3 (v0.88.1 heading), proves the target version.
[^iq1-2]: CHANGELOG.md:1500, "Remove possibility to newArchEnabled=false in 0.82".
[^iq1-3]: packages/react-native/Libraries/BatchedBridge/MessageQueue.js:36, queue and 5 ms flush gap (the old design).
[^iq1-4]: packages/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/ReactRootProjectPlugin.kt:61-82, error text "not supported anymore since React Native 0.82".
[^iq1-5]: packages/react-native/scripts/react_native_pods.rb:545-556, warning for RCT_NEW_ARCH_ENABLED=0; line 148 forces it to "1".
[^iq1-6]: packages/react-native/src/private/featureflags/ReactNativeFeatureFlags.js:300 and scripts/featureflags/ReactNativeFeatureFlags.config.js:250-252, `enableBridgelessArchitecture` default true.
[^iq2-1]: packages/react-native/Libraries/BatchedBridge/MessageQueue.js:36 and :309, flush gap constant and JSON.stringify only in the spy logger (:99) and an error message (:309). Proof: scratch/A/proof-2.txt.
[^iq2-2]: packages/react-native/Libraries/BatchedBridge/BatchedBridge.js:9 and :21-24, `@deprecated` and `__fbBatchedBridge`.
[^iq2-3]: packages/react-native/ReactCommon/jsi/jsi/jsi.h:217 (`HostFunctionType`) and :222 (`HostObject`).
[^iq2-4]: packages/react-native/ReactCommon/react/nativemodule/core/ReactCommon/TurboModule.h:49, `class JSI_EXPORT TurboModule : public jsi::HostObject`.
[^iq3-1]: packages/react-native/ReactCommon/react/renderer/mounting/ShadowTree.h:76 (`class ShadowTree final`) and :31-50 (commit status, mode, source enums).
[^iq3-2]: packages/react-native/ReactCommon/react/renderer/mounting/Differentiator.h:22, `calculateShadowViewMutations`.
[^iq3-3]: packages/react-native/Libraries/ReactNative/FabricUIManager.js:155-211, proxy to `nativeFabricUIManager`.
[^iq3-4]: CHANGELOG.md:469 (UIImplementation removed) and CHANGELOG.md:309 (RCTCxxBridge symbols removed).
[^iq4-1]: packages/react-native/Libraries/TurboModule/TurboModuleRegistry.js:17-46, proxy first, then NativeModules fallback, `get` and `getEnforcing`.
[^iq4-2]: packages/react-native-codegen/src/generators/modules (GenerateModuleH.js, GenerateModuleJavaSpec.js, GenerateModuleJniCpp.js, GenerateModuleObjCpp).
[^iq4-3]: packages/react-native/ReactCommon/react/nativemodule/core/ReactCommon/TurboModule.h:49.
[^iq4-4]: packages/react-native/package.json:183 (HEAD) and :187 (v0.88.1), `codegenConfig` library `FBReactNativeSpec`.
[^iq5-1]: packages/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/ReactRootProjectPlugin.kt:61-82 and CHANGELOG.md:1500.
[^iq5-2]: packages/react-native/scripts/react_native_pods.rb:545-556.
[^iq5-3]: packages/react-native/scripts/react_native_pods.rb:120 (default '1') and :627-630 (flag adds -DRCT_REMOVE_LEGACY_ARCH=1). Also at tag v0.88.1 line 120.
[^iq5-4]: CHANGELOG.md:81, opt-in interop removal flags, both default off.
[^iq5-5]: CHANGELOG.md:1583, `BridgelessReactContext.getCatalystInstance()` deprecated.
[^iq6-1]: tmp/rnw-ch0506/docs/hermes.md:12-18, Hermes is default and bundled per release.
[^iq6-2]: CHANGELOG.md:1038 (v0.84.0, Breaking), "Make Hermes V1 the default engine".
[^iq6-3]: CHANGELOG.md:468 (v0.87.0), "Remove hermesV1Enabled and simplify the code".
[^iq6-4]: packages/react-native/package.json:168 at tag v0.88.1, `hermes-compiler` 260318099.0.5. At HEAD line 164 it is the placeholder `0.0.0`.
[^iq6-5]: tmp/rnw-ch0506/docs/hermes.md:91, release build compiles JS to Hermes bytecode at build time.
[^iq6-6]: CHANGELOG.md:268 (v0.87.1), SwiftPM "Wrong bytecode version" fix.
[^iq6-7]: tmp/rnw-ch0506/docs/hermes.md:95, JavaScriptCore through the community repository.
[^iq6-8]: tmp/rnw-ch0506/docs/hermes.md:31-39, `HermesInternal` check and `.hbc` note.
[^iq7-1]: tmp/rnw-ch0506/website/architecture/threading-model.md:14-19, two threads and thread safety.
[^iq7-2]: tmp/rnw-ch0506/website/architecture/threading-model.md:25-41, render on JS thread, or sync on UI thread.
[^iq7-3]: tmp/rnw-ch0506/website/architecture/render-pipeline.md:77 (commit on background thread) and :98-104 (mount on UI thread, sync if commit ran on UI thread).
[^iq7-4]: tmp/rnw-ch0506/docs/performance.md:22-28, JS thread blocks touches, scroll and native stack run on the main thread.
[^iq8-1]: tmp/rnw-ch0506/website/blog/2024-10-23-the-new-architecture-is-here.mdx:12, Suspense, Transitions, automatic batching, useLayoutEffect.
[^iq8-2]: tmp/rnw-ch0506/website/blog/2024-10-23-the-new-architecture-is-here.mdx:39-48, multiple trees and priorities.
[^iq8-3]: packages/react-native/package.json:149 at tag v0.88.1, `"react": "^19.3.0"`.
[^iq8-4]: tmp/rnw-ch0506/website/architecture/threading-model.md:61, render phase is interruptible.
[^iq8-5]: tmp/rnw-ch0506/docs/optimizing-javascript-loading.md:23, lazy loading with Suspense.
[^iq8-6]: tmp/rnw-ch0506/website/blog/2024-10-23-the-new-architecture-is-here.mdx:188 and :190, interop layer limits and Rules of React.
[^iq9-1]: packages/metro-config/src/index.flow.js:73-77 (HEAD), and same flag at v0.88.1 line 95.
[^iq9-2]: node_modules/metro-transform-worker/src/index.js:180-208 (installed metro 0.84.3, yarn.lock pins 0.87.2, which could not be fetched), only inlinePlatform and constantFoldingPlugin. No tree shaking at 0.87 not checked directly (unverified).
[^iq9-3]: tmp/rnw-ch0506/docs/optimizing-javascript-loading.md:88-156, inline requires, Expo default, blockList.
[^iq9-4]: tmp/rnw-ch0506/docs/debugging-release-builds.md:23-72, source maps on Android and iOS, metro-symbolicate.
[^iq10-1]: packages/react-native/src/private/animated/NativeAnimatedHelper.js:418-439, warning (:433-436) and forced native driver (:418-425). Flag config line 1108.
[^iq10-2]: tmp/rnw-ch0506/docs/animations.md:540 (one driver per value) and :564 (only non-layout props, transform and opacity work, Flexbox and position do not).
[^iq10-3]: packages/react-native/scripts/featureflags/ReactNativeFeatureFlags.config.js:74-84, default false, canary. Same at v0.88.1.
[^iq10-4]: packages/react-native/scripts/featureflags/ReactNativeFeatureFlags.config.js:1009-1018, default false, experimental.
[^iq11-1]: tmp/refresh/scratch/ch11-15/rnw/docs/scrollview.md:14, ScrollView renders all children at once.
[^iq11-2]: tmp/refresh/scratch/ch11-15/rnw/docs/performance.md:58, names FlashList and Legend List as third-party lists.
[^iq11-3]: packages/virtualized-lists/Lists/VirtualizedListProps.js:332-334, `windowSize ?? 21`.
[^iq11-4]: packages/virtualized-lists/Lists/VirtualizedListProps.js:303-314 (`initialNumToRender` 10, `maxToRenderPerBatch` 10) and VirtualizedList.js:2110 (`updateCellsBatchingPeriod ?? 50`).
[^iq11-5]: tmp/refresh/scratch/ch11-15/rnw/docs/flatlist.md:338,517-523,153, FlatList wraps VirtualizedList, `getItemLayout`, `keyExtractor`.
[^iq11-6]: packages/react-native/Libraries/Lists/FlatList.js:161-168, `removeClippedSubviews` default.
[^iq11-7]: packages/react-native/scripts/featureflags/ReactNativeFeatureFlags.config.js:1217-1218, flag default false.
[^iq11-8]: tmp/refresh/scratch/ch11-15/rnw/docs/optimizing-flatlist-configuration.md:72-82, windowSize tradeoff.
[^iq11-9]: tmp/refresh/scratch/ch11-15/rnw/docs/sectionlist.md:275, headers stick on iOS by default. Source: packages/react-native/Libraries/Lists/SectionList.js:250-251, `_stickySectionHeadersEnabled ?? Platform.OS === 'ios'`.
[^iq11-10]: tmp/refresh/scratch/ch11-15/rnw/docs/sectionlist.md:88, SectionList wraps VirtualizedList. Source: packages/react-native/Libraries/Lists/SectionList.js:257, renders `VirtualizedSectionList`.
[^iq11-11]: tmp/refresh/scratch/ch11-15/rnw/docs/flatlist.md:341,509 and sectionlist.md:91,141, `PureComponent` and `extraData`. Source: packages/react-native/Libraries/Lists/FlatList.js:310, `class FlatList extends React.PureComponent`.
[^iq12-1]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:139,167-171, Components and Profiler panels.
[^iq12-2]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:153, React Compiler mention in the docs.
[^iq12-3]: tmp/refresh/scratch/ch11-15/rnw/docs/optimizing-flatlist-configuration.md:96-118, `React.memo` with compare function.
[^iq12-4]: tmp/refresh/scratch/ch11-15/rnw/website/blog/2025-02-19-react-native-0.78.mdx:49-51, compiler setup in 0.78 (compiler only plus Babel plugin).
[^iq12-5]: tmp/refresh/interview/scratch/C/proof-12.txt, grep count 0 for `react-compiler` in repo, only `hermes-compiler` in node_modules.
[^iq12-6]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:153, "Memo ✨" badge. Source: packages/debugger-frontend/dist/third-party/front_end/third_party/react-devtools/react-devtools.js, string "✨ This component has been auto-memoized by the React Compiler." (grep, minified, no stable line).
[^iq13-1]: tmp/refresh/scratch/ch11-15/rnw/docs/flexbox.md:14, the three default differences and single-number `flex`.
[^iq13-2]: packages/react-native/ReactCommon/react/renderer/components/view/YogaLayoutableShadowNode.cpp:72-73, Fabric Yoga config and node.
[^iq13-3]: packages/react-native/ReactCommon/yoga/yoga/style/Style.h:922-935, Yoga defaults (`flexDirection_` Column at 922-923, `alignContent_` FlexStart at 927, `alignItems_` Stretch at 928, `flexWrap_` NoWrap, `boxSizing_` BorderBox at 935).
[^iq13-4]: packages/react-native/ReactCommon/yoga/yoga/style/Style.h:48-49, YGNodeStyle.cpp:201 and node/Node.cpp:488-489, `DefaultFlexShrink` 0, web 1 with `useWebDefaults`. Config.h:86 default false. Nothing under ReactCommon/react/renderer calls `setUseWebDefaults` (grep).
[^iq13-5]: packages/react-native/Libraries/StyleSheet/StyleSheetTypes.js:650-660, gap semantics.
[^iq13-6]: tmp/refresh/scratch/ch11-15/rnw/docs/flexbox.md:2087, gap accepts numbers or percentage strings on the New Architecture.
[^iq13-7]: tmp/refresh/scratch/ch11-15/rnw/docs/height-and-width.md:83, percentage dimensions need a parent with a defined size.
[^iq13-8]: packages/react-native/ReactCommon/react/renderer/components/view/YogaStylableProps.cpp:125-141, props set Yoga style (`REBUILD_FIELD_SWITCH_CASE_YSP`, `REBUILD_FIELD_YG_GUTTER(gap, ...)` at 141).
[^iq14-1]: tmp/refresh/scratch/ch11-15/rnw/docs/platform-specific-code.md:29,123-138, `select` keys and `.native.js`.
[^iq14-2]: node_modules/metro-resolver/src/resolve.js:454-469, platform, then `.native`, then plain extension (metro 0.84.3).
[^iq14-3]: packages/react-native/Libraries/Utilities/Platform.ios.js:80-82 and Platform.android.js:73-82, `select` fallback order.
[^iq14-4]: packages/metro-config/src/index.flow.js:39, `platforms: ['android', 'ios']`.
[^iq14-5]: node_modules/metro/src/lib/transformHelpers.js:34 (`inlinePlatform: true`), node_modules/metro-transform-worker/src/index.js:~198-210 (`constantFoldingPlugin` only `if (!options.dev)`), packages/react-native-babel-preset/src/inline-platform-plugin.js. Run proof: tmp/refresh/interview/scratch/FC-2/plat.js (input `Platform.OS === 'ios' ? A : B` and `Platform.select`, output `'IOS_ONLY'` and `'SEL_IOS'` after the plugin and constant folding).
[^iq15-1]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:107-116, Performance panel since 0.83.
[^iq15-2]: tmp/refresh/scratch/ch11-15/rnw/docs/profiling.md:8,19, Instruments, Android Studio Profiler, `systrace` removed.
[^iq15-3]: tmp/refresh/scratch/ch11-15/rnw/docs/profiling.md:10, make sure Development Mode is off.
[^iq15-4]: tmp/refresh/scratch/ch11-15/rnw/docs/performance.md:14 and debugging.md:98, Perf Monitor and two frame rates.
[^iq15-5]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:167-171, React Profiler panel.
[^iq15-6]: tmp/refresh/scratch/ch11-15/rnw/docs/react-native-devtools.md:124-128, Memory panel.
[^iq16-1]: tmp/refresh/scratch/ch11-15/rnw/docs/turbo-native-modules.md:61-74, official spec example with `Spec extends TurboModule` and `getEnforcing`.
[^iq16-2]: tmp/refresh/scratch/ch11-15/rnw/docs/turbo-native-modules.md:104-110, `codegenConfig` keys `name`, `type`, `jsSrcsDir`, `android.javaPackageName`.
[^iq16-3]: packages/react-native/Libraries/TurboModule/TurboModuleRegistry.js:35-47, `get` returns null and `getEnforcing` throws via invariant (HEAD 9c7b0f5fafd).
[^iq16-4]: packages/rn-tester/package.json:41-47, real `codegenConfig` with `name`, `type: all`, `jsSrcsDir`.
[^iq16-5]: tmp/refresh/scratch/ch11-15/rnw/docs/turbo-native-modules-android.md:10-25,124-133 and turbo-native-modules-ios.md:53-60, generated `NativeLocalStorageSpec`, `BaseReactPackage`. Docs line turbo-native-modules.md:138 shows `bundle exec pod install`.
[^iq16-6]: CHANGELOG.md:1041-1045 (v0.84.0 Breaking, "Remove TurboCxxModule", "Remove RCTCxxModule", "Remove CxxModule support from CatalystInstance").
[^iq16-8]: packages/react-native-codegen/src/generators/modules/GenerateModuleObjCpp/serializeMethod.js:118-121, a `PromiseTypeAnnotation` return adds `resolve` and `reject` blocks. Other return types are plain returns.
[^iq16-7]: https://reactnative.dev/docs/turbo-native-modules-introduction (external docs, TurboModule model). Local copy: tmp/refresh/scratch/ch11-15/rnw/docs/turbo-native-modules.md.
[^iq17-1]: packages/rn-tester/NativeComponentExample/js/MyNativeViewNativeComponent.js:13-95, spec with `CodegenTypes.Float`, `BubblingEventHandler`, `codegenNativeCommands`, `codegenNativeComponent` (HEAD).
[^iq17-2]: tmp/refresh/scratch/ch11-15/rnw/docs/fabric-native-components.md:62-117, official spec walk-through.
[^iq17-3]: tmp/refresh/scratch/ch11-15/rnw/docs/fabric-native-components-ios.md:77-82,127-159, `RCTViewComponentView`, `updateProps:oldProps:`, `self.eventEmitter.onScriptLoaded`.
[^iq17-4]: tmp/refresh/scratch/ch11-15/rnw/docs/fabric-native-components-android.md:76-85,197, `eventDispatcher.dispatchEvent`.
[^iq17-5]: tmp/refresh/scratch/ch11-15/rnw/docs/the-new-architecture/fabric-component-native-commands.md:20-50, `codegenNativeCommands` with `supportedCommands: ['reload']`.
[^iq17-6]: tmp/refresh/scratch/ch11-15/rnw/docs/fabric-native-components.md:129-138, `ios.componentProvider` and `android.javaPackageName`.
[^iq17-7]: tmp/refresh/scratch/ch11-15/rnw/docs/fabric-native-components-android.md:344-366, component registered in a `BaseReactPackage`.
[^iq17-9]: packages/react-native/scripts/codegen/generate-artifacts-executor/generateRCTThirdPartyComponents.js:120-131, `[DEPRECATED] ... should add the 'ios.componentProvider' property`.
[^iq17-8]: CHANGELOG.md:319-321 (v0.87.0), legacy view manager interop still exists and is gated by `RCT_REMOVE_LEGACY_COMPONENT_INTEROP`.
[^iq18-1]: https://docs.expo.dev/workflow/continuous-native-generation.md (external, fetched 2026-10-29, page dated September 25, 2026), CNG, prebuild, `--clean`, EAS Build behavior, brownfield note, "managed vs bare deprecated".
[^iq18-2]: https://docs.expo.dev/versions/latest/ (external), "All Expo SDK packages work in any React Native app", `npx install-expo-modules`.
[^iq18-3]: https://docs.expo.dev/develop/development-builds/introduction.md (external), dev build commands and when to rebuild.
[^iq18-4]: https://docs.expo.dev/versions/latest/ (external), table row "58.0.0 | 0.88 | 19.3.0 | ... | 22.13.x".
[^iq18-5]: private/helloworld/android/gradle.properties:11, `newArchEnabled=true`.
[^iq18-6]: CHANGELOG.md:1500,1505 (v0.82.0 Breaking), opt-out removed on Android and iOS.
[^iq19-1]: https://reactnavigation.org/docs/native-stack-navigator (external, 7.x), `UINavigationController`, `Fragment`, issues go to react-native-screens.
[^iq19-2]: https://reactnavigation.org/docs/deep-linking/ (external, 7.x), `linking` prop, `prefixes`, cold and warm cases, `singleTask`, `autoVerify`, `getInitialURL`, `subscribe`, test commands.
[^iq19-3]: https://reactnavigation.org/docs/configuring-links (external), the `config` map from paths to screens (page not fetched, referenced from the deep-linking page).
[^iq19-4]: packages/react-native/Libraries/Linking/Linking.js:32,49,64,90, `addEventListener`, `openURL`, `canOpenURL`, `getInitialURL` (HEAD).
[^iq19-5]: packages/react-native/Libraries/AppState/AppState.js:31-32,124-160, status type and event names `change`, `memoryWarning`, `blur`, `focus` (HEAD).
[^iq20-1]: tmp/refresh/scratch/ch11-15/rnw/docs/upgrading.md:16-51, Upgrade Helper flow, URL https://react-native-community.github.io/upgrade-helper/.
[^iq20-2]: https://docs.expo.dev/workflow/continuous-native-generation.md (external), "upgrade npm dependencies, app config, and re-run `npx expo prebuild --clean`". The `expo install --fix` command is from https://docs.expo.dev/versions/latest/ (canary section).
[^iq20-3]: CHANGELOG.md:1500,1505 (v0.82.0 Breaking), Android and iOS opt-out removed.
[^iq20-4]: CHANGELOG.md:1038 (Hermes V1 default), 1042-1045 (CxxModule removals), 1054 (`unstable_shouldEnableLegacyModuleInterop` removed), 1059 (iOS "Remove legacy arch by default"), all in v0.84.0.
[^iq20-5]: CHANGELOG.md:833 (jest preset package), 832 Node drop line, v0.85.0 Breaking.
[^iq20-6]: CHANGELOG.md:285 (Node >= 22.13.0), 292 (Strict TypeScript API), 296 (AGP v9), v0.87.0 Breaking. The deep import restriction is CHANGELOG.md:278, same Breaking list.
[^iq20-7]: CHANGELOG.md:319-321 (v0.87.0), interop gates `RCT_REMOVE_LEGACY_COMPONENT_INTEROP` and `RCT_REMOVE_LEGACY_MODULE_INTEROP`.
[^iq21-1]: react-native-new-arch-research/17-Testing-React-Native-Apps.md, "Test pyramid and testing trophy" and "Part 2" intro. Opinion, not a measured result.
[^iq21-2]: packages/jest-preset/jest-preset.js (preset keys) and jest/setup.js (View and other mocks), RN checkout.
[^iq21-3]: tmp/refresh/interview/scratch/IQ-TESTING/proof-22.txt, Jest run in Node, 3 passed. No layout engine runs.
[^iq21-4]: The testing chapter, section "A sensible CI pipeline for an RN app". Team choice, not a rule from a source.
[^iq21-5]: private/react-native-fantom/__docs__/README.md (experimental, internals only), root package.json:46-47 (`"test": "jest"`, `"fantom"`), packages/rn-tester/README.md:3.
[^iq22-1]: Tarballs from `npm pack react-native@<v> --before=2026-10-30`: 0.84.0 has 33 entries under `package/jest/` and `jest-preset.js`, 0.85.0 and 0.86.0 have only `jest-preset.js`, 0.87.0 has none. Proof: tmp/refresh/interview/scratch/IQ-TESTING/proof-preset.txt.
[^iq22-2]: react-native@0.85.0 `package/jest-preset.js` lines 12-24 (stub, migration error) and CHANGELOG.md:833 (v0.85.0 "Move Jest preset to new package") and CHANGELOG.md:282 (v0.87.0 preset removed from `react-native`).
[^iq22-3]: packages/jest-preset/package.json (name `@react-native/jest-preset`, engines node >= 22.13.0) and `npm view @react-native/jest-preset version` = 0.88.1 (2026-10-29).
[^iq22-4]: `npm view @testing-library/react-native version peerDependencies` = 14.1.0, jest >=29.0.0, react >=19.0.0, react-native >=0.78, test-renderer ^1.0.0. Promise returns: the testing chapter footnote ts-unit-11. Run proof: proof-22.txt.
[^iq22-5]: `npm view @testing-library/jest-native deprecated` (2026-10-29): "Please use the built-in Jest matchers available in @testing-library/react-native v12.4+".
[^iq22-6]: tmp/refresh/testing/scratch/unit/src/more.test.js (TurboModuleRegistry.get spy, fake timers with `{finished: true}`), rerun 2026-10-29: 2 suites, 3 tests passed. Also tmp/refresh/interview/scratch/IQ-TESTING/proof-22.txt.
[^iq23-1]: https://docs.maestro.dev/get-started/how-maestro-works.md (black box, driver app, accessibility tree). `gh api repos/mobile-dev-inc/maestro/releases/latest` = cli-2.12.0. Syntax check proof: the testing chapter footnote ts-e2ex-12.
[^iq23-2]: Detox README.md:66-67 (RN 0.77 to 0.84 compatible), docs/articles/how-detox-works.md (sync list), issues wix/Detox#4963 and #4973. `npm view detox version` = 20.51.4 (2026-10-29). Via the testing chapter footnote ts-e2ex-4, -6, -8.
[^iq23-3]: `npm view appium version` = 3.9.0 (2026-10-29). The testing chapter section "Appium 3 with WebdriverIO".
[^iq23-4]: packages/react-native/ReactAndroid/src/main/java/com/facebook/react/uimanager/ReactAccessibilityDelegate.kt:175-181 and https://docs.maestro.dev/get-started/supported-platform/react-native.md. Via the testing chapter footnote ts-e2ex-18, -19.
[^iq23-5]: The testing chapter section "Flakiness: causes and fixes". Advice, not a measured result.
[^iq24-1]: The testing chapter section "Snapshot testing". https://testing-library.com/docs/guiding-principles (not re-fetched, opinion).
[^iq24-2]: https://react.dev/warnings/react-test-renderer (fetched 2026-10-29): deprecated, warning on `ReactTestRenderer.create()`, "will remain available on NPM but will not be maintained and may break with new React features".
[^iq24-3]: tmp/refresh/interview/scratch/IQ-TESTING/proof-22.txt, "Snapshots: 1 passed".
[^iq24-4]: `npm view react-test-renderer@19.3.1 deprecated` returns empty (2026-10-29).
[^iq24-5]: https://github.com/callstack/react-native-testing-library/releases/tag/v14.0.0 (breaking: "Replaced the deprecated React Test Renderer with Test Renderer") and `npm view @testing-library/react-native@14.1.0 peerDependencies.test-renderer` = ^1.0.0.
[^iq25-1]: The testing chapter section "A sensible CI pipeline for an RN app" (stage table, release gate).
[^iq25-2]: The testing chapter CI sample. Parsed again with PyYAML on 2026-10-29: tmp/refresh/testing/scratch/FC-1/ci.yml gives jobs static, android-e2e, release-gate. Latest releases by `gh api`: actions/checkout v7.0.1, actions/setup-node v7.1.0, ReactiveCircus/android-emulator-runner v2.38.0.
[^iq25-3]: https://docs.github.com/en/billing/reference/actions-runner-pricing (fetched 2026-10-29 by the the testing chapter author, not re-fetched): macOS 0.062 USD, Linux 2 core 0.006 USD per minute. Ratio 0.062 / 0.006 is about 10.
[^iq25-4]: https://github.com/ReactiveCircus/android-emulator-runner README (KVM, one shell command per `script` line). Via the testing chapter footnote ts-history-26.
[^iq25-6]: The testing chapter table "Device clouds and CI services". Prices are search-snippet level and unverified there.
[^iq25-7]: https://docs.expo.dev/eas/workflows/examples/e2e-tests/ (last updated 2026-07-22). Via the testing chapter footnote ts-e2e-9.
[^iq26-1]: `npm view @mobilenext/mobile-mcp version` = 1.0.14 and `npm view appium-mcp version` = 1.99.1 (2026-10-29). Maestro MCP: https://docs.maestro.dev/get-started/maestro-mcp. Tool counts and Expo MCP: the testing chapter footnote ts-ai-2 to ts-ai-6.
[^iq26-2]: The testing chapter sections "Accessibility tree or screenshot", "Risks", and "A practical workflow". appium-mcp README trust model: the testing chapter footnote ts-ai-4.
[^iq26-3]: https://docs.expo.dev/mcp/ ("prefer testID as it is resilient to layout changes"). Via the testing chapter footnote ts-ai-6.
[^iq26-4]: https://docs.maestro.dev/reference/commands-available/assertwithai (fetched again 2026-10-29): "experimental", `optional` default true, set `optional: false` to stop the test.
[^iq27-1]: https://docs.autosana.ai/code-managed-files.md and https://docs.autosana.ai/introduction (fetched 2026-10-29). Via the testing chapter footnotes ts-asa-2 and ts-asa-3.
[^iq27-2]: https://docs.autosana.ai/app-build-guide.md (fetched 2026-10-29). Via ts-asa-4.
[^iq27-3]: https://autosana.ai/pricing (fetched 2026-10-29). Via ts-asa-5.
[^iq27-4]: https://autosana.ai/security (fetched 2026-10-29): disclosure address only, SOC 2 Type 1 on the footer. Via ts-asa-9.
[^iq27-5]: The testing chapter subsection "AI-native test services: Autosana and peers" and "Risks". Judgment, not a measured result.
