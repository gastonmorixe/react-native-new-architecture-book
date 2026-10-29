---
title: "Testing React Native apps"
chapter: "17"
created_at: "2026-10-29T14:00:00-04:00"
updated_at: "2026-10-29T14:00:00-04:00"
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
tags: [react-native, testing, jest, testing-library, detox, maestro, appium, ci, ai-agents, mcp]
audit:
  status: "partial"
taillog:
  - "2026-10-29T14:00:00-04:00 | New chapter. Four research workers (unit, e2e, history and CI, AI). Fact-check pass pending."
  - "2026-10-29T16:00:00-04:00 | Three adversarial fact-check workers re-verified all four parts. Part 2 was rewritten with Detox, Maestro and Appium detail. Open items are in the CHANGELOG."
---

# Chapter 18: Testing React Native Apps

This chapter explains how to test a React Native app in late 2026. It covers unit and component tests, end-to-end tests, the history of the tools, device clouds and CI, and the effect of agentic AI. Tool versions and project status were checked on 2026-10-29. Each fact has a footnote. Code marked "not run" was not executed.


## Part 1: Unit, component, and integration tests

This section covers tests that run in Node, not on a device. These tests are fast. They run on every commit. Checked on 2026-10-29 against React Native 0.88.1 and React 19.3.1.[^ts-unit-1]

### Jest and the React Native preset

Jest is the default test runner for React Native apps. The runner needs a preset. The preset sets the transform, the module resolver, the test environment, and a setup file that mocks parts of React Native.

The preset moved to its own package. In 0.84 the preset lived inside the `react-native` package (`jest-preset.js` and a `jest/` folder).[^ts-unit-2] In 0.85 the `react-native` package keeps only a stub. The stub re-exports `@react-native/jest-preset`. If that package is missing, the stub throws an error that tells you to install it.[^ts-unit-3] The new package first appeared on npm on 2026-02-19 (a 0.85.0 nightly). It ships with each RN release (0.88.1 on 2026-10-27).[^ts-unit-4]

Migration takes two steps.

1. Install `@react-native/jest-preset` as a dev dependency. Use the same version as `react-native`.
2. Change `jest.config.js`.

```js
// jest.config.js (run: yes, see proof-unit-jest.txt)
module.exports = {preset: '@react-native/jest-preset'};
```

The old value was `preset: 'react-native'`.[^ts-unit-3] The package needs Node 22.13 or newer and a peer of React 19.2.3 or newer.[^ts-unit-5]

What the preset configures:[^ts-unit-6]

| Key | Value |
| --- | --- |
| `haste` | React Native haste settings |
| `resolver` | custom `jest/resolver.js` |
| `transform` | babel-jest with the RN Babel preset, plus an asset file transformer |
| `transformIgnorePatterns` | ignore `node_modules` except `react-native`, `@react-native/*`, and `@react-native-community/*` |
| `setupFiles` | `jest/setup.js` |
| `testEnvironment` | `jest/react-native-env.js` (a Node-based environment) |

The setup file mocks these modules: `NativeModules`, `AppState`, `AccessibilityInfo`, `ActivityIndicator`, `Clipboard`, `RefreshControl`, `ScrollView`, `TextInput`, `View`, `Image`, `Linking`, `Modal`, `Text`, `UIManager`, `useColorScheme`, `Vibration`, `NativeComponentRegistry`, and `requireNativeComponent`.[^ts-unit-7] Layout does not run. A `View` is a plain mock. Because of this, `getBoundingClientRect` and real layout values are not available in Jest.

If your app has a Jest 29 setup, note that the preset depends on `babel-jest` 29 and `jest-environment-node` 29.[^ts-unit-5] Jest 30.5.2 is the latest Jest (checked 2026-10-29).[^ts-unit-8] The scratch project ran Jest 30.5.2 with the 0.88.1 preset and passed.[^ts-unit-9]

### Mocking native modules and TurboModules

JavaScript code reaches native code through `NativeModules` or `TurboModuleRegistry`. Jest has no native side. You must replace the module.

- For modules the preset already mocks, use the mock as is.
- For one module in one test, use `jest.spyOn` on the JS wrapper (for example `Share.share`).
- For a third-party module, use `jest.mock('name', factory)` in a setup file you list in `setupFiles`.
- For your own TurboModule, mock the spec file that calls `TurboModuleRegistry.getEnforcing`.

The New Architecture changes one thing. TurboModules load lazily and through JSI, not through the old bridge. Old tests that set `NativeModules.Foo = {...}` still work only for modules that code reads through `NativeModules`. Code that reads `TurboModuleRegistry.get('Foo')` needs a mock of the registry or of the spec file. The scratch test spied on `TurboModuleRegistry.get` and passed.[^ts-unit-9]

Keep mocks thin. A mock that copies native logic hides real bugs. Cover the real native path with an end-to-end test (see the end-to-end chapter section).

### React Native Testing Library

React Native Testing Library (RNTL) renders components and queries them like a user does. The latest version is 14.1.0 (published 2026-10-08).[^ts-unit-10] It needs React 19 or newer, React Native 0.78 or newer, Node 22.13 or newer, and the `test-renderer` package. Jest 29 or newer is an optional peer.[^ts-unit-10]

Version 14 changed the rendering API. `render`, `renderHook`, and the event helpers return Promises. You must `await` them.[^ts-unit-11] RNTL 14 uses `test-renderer` in place of `react-test-renderer`. The RNTL 14.0.0 release notes list this as a breaking change and add a peer dependency on `test-renderer` 1.x.[^ts-unit-12] The reason: React deprecated `react-test-renderer` in React 19. React says the package stays on npm, is not maintained, and may break with new React features.[^ts-unit-13] The old package still installs (19.3.1).

Query rules, in order of preference:

| Query | Use for |
| --- | --- |
| `getByRole` (with `name`) | buttons, links, switches |
| `getByLabelText` | form fields with an accessibility label |
| `getByPlaceholderText` | text inputs |
| `getByText` | static text |
| `getByTestId` | last resort |

Use `getBy*` when the element must exist. Use `queryBy*` to assert absence. Use `findBy*` to wait for an element.

`userEvent` or `fireEvent`: prefer `userEvent`. It runs the full sequence of events that a real touch makes (press in, press out, focus, change). `fireEvent` sends one event to one handler. It can pass in a test when a real user could not trigger the handler.[^ts-unit-14]

```js
// src/Greeter.test.js (run: yes, 1 passed, Jest 30.5.2, RNTL 14.1.0, RN 0.88.1)
import React from 'react';
import {Share} from 'react-native';
import {render, screen, userEvent} from '@testing-library/react-native';
import {Greeter} from './Greeter';

test('shares a greeting', async () => {
  const spy = jest.spyOn(Share, 'share').mockResolvedValue({action: 'sharedAction'});
  const user = userEvent.setup();
  await render(<Greeter />);
  await user.type(screen.getByPlaceholderText('Name'), 'Ana');
  await user.press(screen.getByRole('button', {name: 'Share'}));
  expect(spy).toHaveBeenCalledWith({message: 'Hello Ana'});
  expect(await screen.findByText('Shared for Ana')).toBeOnTheScreen();
});
```

The built-in matchers (`toBeOnTheScreen`, `toHaveTextContent`) replace `@testing-library/jest-native`. That package is deprecated.[^ts-unit-15] The `@testing-library/react-hooks` package is also old (last 8.0.1). Use `renderHook` from RNTL.[^ts-unit-10]

Async utils: `findBy*`, `waitFor`, and `waitForElementToBeRemoved`. Prefer `findBy*`. Do not put side effects inside `waitFor`.

### Testing hooks

Use `renderHook` from RNTL. Test the hook through the component that uses it when the hook depends on context or navigation. Test it alone when it holds pure logic. Use `act` (re-exported by RNTL) for state changes you trigger yourself.

### Fake timers and Animated

Use `jest.useFakeTimers()`. Then move time with `jest.advanceTimersByTime(ms)`. With `useNativeDriver: false`, `Animated.timing` finishes when you advance past its duration. The scratch test did this and the callback got `{finished: true}`.[^ts-unit-9] With the native driver, the animation runs on the UI thread. Jest cannot see it. Test only that the animation starts. Check the final look on a device.

### Network: MSW

Mock Service Worker (MSW) intercepts `fetch` at the network layer. This tests your real data code without stubs. The latest version is 3.0.3 (modified 2026-10-10).[^ts-unit-16] In React Native you use `msw/node` with `setupServer` in a Jest setup file. Mark: I did not run an MSW test in the scratch project (not run). RN has its own `fetch` and `XMLHttpRequest` polyfills, so check that your MSW version can patch them before you adopt it.

### Testing navigation

Wrap the screen in the navigation container your app uses (for example React Navigation's `NavigationContainer`) inside a test helper. Mock native screens modules if the library needs them. Assert on what the user sees after a press, not on the router's internal state. Not run in scratch.

### Snapshot testing

Snapshot tests store a rendered tree and compare it on each run. They fell out of favor for four reasons. Snapshots are large. Nobody reads the diffs. Engineers update them without review. And they test structure, not behavior. Use small inline snapshots for stable, tiny output (an error object, a style). Use queries and matchers for behavior. This is an opinion, shared by the Testing Library guidance, not a measured result.[^ts-unit-17]

### Test pyramid and testing trophy

The pyramid says: many unit tests, fewer integration tests, few end-to-end tests. The trophy says: write most tests at the integration level (a screen with real child components and mocked edges), keep a base of static checks (TypeScript, ESLint), and few end-to-end tests. For mobile, the trophy fits better. Most bugs sit where components, state, and the network meet. A unit test of a tiny function misses those bugs. Both models are opinions, not rules.

| Layer | Tool | Speed | Catches |
| --- | --- | --- | --- |
| Static | TypeScript, ESLint | seconds | type and style errors |
| Unit | Jest | ms | pure logic |
| Component/integration | Jest + RNTL + MSW | ms to s | screen behavior |
| End to end | Maestro, Detox (other sections) | minutes | real native paths |

### Coverage

Run `jest --coverage`. Set `coverageThreshold` for changed code, not only a global number. A high number does not prove the tests check anything. Exclude generated files and native spec files.

### How the React Native repo tests itself

The RN repo uses three layers.

- Jest unit tests in `__tests__` folders, run with `yarn test`.[^ts-unit-18]
- Fantom integration tests, files ending in `-itest.js`, run with `yarn fantom`.[^ts-unit-19]
- RNTester, an app that shows each core component and API for manual checks and native integration tests.[^ts-unit-20]

Fantom is "the new integration testing and benchmarking tool for React Native". It runs JavaScript in Hermes with Fabric, C++ TurboModules, and Bridgeless in a headless native tester. Layout is real, so `getBoundingClientRect` returns real values.[^ts-unit-19] The README marks it as experimental. It is limited to React Native internals, and tests must live in `packages/react-native`. It is for engineers who work on React Native. It is not for app teams. The README says only that Meta may later open it to product code.[^ts-unit-19] Do not plan your app tests on it.

## Part 2: End-to-end and device tests

End-to-end (E2E) tests run the real app on a device or simulator. They test the whole stack: JavaScript, native modules, and the OS. They are slow and costly, so write few of them. Cover the critical user journeys only.

### Status of the tools (checked 2026-10-29)

| Tool | Latest version | Last release / commit | Status |
| --- | --- | --- | --- |
| Detox | 20.51.4 on npm (`latest` tag), GitHub release 20.51.3 [^ts-e2e-1] | npm 20.51.4 published 2026-06-16, GitHub release 2026-05-30, last commit 2026-10-27 [^ts-e2ex-1][^ts-fc3-1] | Maintained |
| Maestro CLI | 2.12.0 [^ts-e2e-2] | release 2026-10-26, commit 2026-10-28 [^ts-e2e-2] | Maintained |
| Appium | 3.9.0 [^ts-e2e-3] | npm 2026-10-27, commit 2026-10-28 [^ts-e2e-3] | Maintained |
| Appium UiAutomator2 driver | 8.7.3 [^ts-e2e-3] | 2026-10-28 | Maintained |
| Appium XCUITest driver | 12.22.4 [^ts-e2e-3] | 2026-10-29 | Maintained |
| WebdriverIO | 10.1.0 [^ts-e2ex-2] | npm 2026-10-18 | Maintained |
| Playwright | 1.64.1 [^ts-e2e-4] | release 2026-10-14 | Maintained |
| Storybook for React Native | 10.7.0 [^ts-e2e-5] | release 2026-10-13 | Maintained |
| Chromatic CLI | 18.13.5 [^ts-e2e-6][^ts-fc3-1] | npm 2026-10-29 | Maintained (vendor product) |
| Argos CLI | 6.11.0 [^ts-e2e-6] | npm 2026-10-21 | Maintained |
| react-native-owl | 1.5.0 [^ts-e2e-6] | npm 1.5.0 published 2025-01-14, last repo push 2025-01-15 [^ts-e2ex-3][^ts-fc3-1] | Stale. No repo push for 21 months. |

The word "maintained" means a release or a commit in the last 60 days.

### Detox

Detox is a gray box tool from Wix. A test runs in Node.js with Jest. The app runs on a simulator or emulator. A native Detox client lives inside the app. The two sides talk over a web socket through a small Detox server [^ts-e2ex-4].

#### How the synchronization works

Detox watches the app state and waits until the app is idle before it runs the next test step. The Detox docs list what it watches: network requests, the native main thread, UI layout (including the Yoga shadow queue), timers (`setTimeout`), animations (Animated and Reanimated), the React Native JavaScript thread, and the native modules thread [^ts-e2ex-4]. The docs also list the React Native bridge, but only for apps that do not use the New Architecture [^ts-e2ex-4].

This sync removes most `sleep()` calls. It has a cost. An endless animation, a polling timer, or a long request keeps the app "busy" and the test hangs. Detox logs the busy tasks when `session.debugSynchronization` is on. The setting is on by default [^ts-e2ex-4].

#### A minimal config and test

The Detox demo app in the repo shows the shape of a config: `apps`, `devices`, and `configurations` [^ts-e2ex-5]. The sample below is a reduced version. It is not run.

```js
// .detoxrc.js (reduced from the repo demo, not run)
module.exports = {
  testRunner: { args: { config: 'e2e/jest.config.js', _: ['e2e'] } },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Debug-iphonesimulator/MyApp.app',
      build: 'xcodebuild -workspace ios/MyApp.xcworkspace -scheme MyApp -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
      build: 'cd android && ./gradlew assembleDebug assembleAndroidTest -DtestBuildType=debug',
      reversePorts: [8081],
    },
  },
  devices: {
    simulator: { type: 'ios.simulator', device: { type: 'iPhone 15' } },
    emulator: { type: 'android.emulator', device: { avdName: 'Pixel_8_API_35' } },
  },
  configurations: {
    'ios.sim.debug': { device: 'simulator', app: 'ios.debug' },
    'android.emu.debug': { device: 'emulator', app: 'android.debug' },
  },
};
```

```js
// e2e/login.test.js (not run)
describe('Login', () => {
  beforeAll(async () => { await device.launchApp({ newInstance: true }); });
  it('shows the welcome title', async () => {
    await element(by.id('login-button')).tap();
    await expect(element(by.id('home-title'))).toBeVisible();
  });
});
```

Run it with `npx detox build -c ios.sim.debug` and then `npx detox test -c ios.sim.debug`. These commands are the documented flow. I did not run them because this machine had no device session.

#### New Architecture support: what is proven

- The Detox README says RN 0.77 to 0.84 is fully compatible with the New Architecture. It says newer RN versions "might work" but the team has not tested them in depth [^ts-e2ex-6].
- The Detox repo builds its own demo against `react-native` 0.85.2 (package.json at HEAD) [^ts-e2ex-7]. A CI line in the demo config handles 0.85 iOS build flags [^ts-e2ex-5].
- Open issue 4963 (opened 2026-07-02, last update 2026-09-03) reports that Detox 20.51.3 fails on Android with RN 0.85.3, New Architecture, bridgeless. The idling resource looks up the private field `mMountItemDispatcher` and gets `NoSuchFieldException` [^ts-e2ex-8]. A comment of 2026-09-03 says the crash did not reproduce on RN 0.86.2 and that the field still exists there. Issue 4973 (open) reports that network sync misses OkHttp clients outside `NetworkingModule` on Expo SDK 56+, seen on Detox 20.51.4 with RN 0.86.2 [^ts-e2ex-8][^ts-fc3-2].
- Nothing in the README, releases, or issues names RN 0.88. I found no proof that Detox 20.51.4 works on RN 0.88.

So the proven state for 0.88 is "not documented and not tested by the Detox team". Detox depends on private RN internals, so each RN minor version can break it. Run a spike on your exact RN version before you adopt it.

### Maestro

Maestro is a black box tool. The CLI sends commands to the device. It reads the screen through the accessibility tree, not through app code. The Maestro docs call this the "arm's length" model. They also say you do not need an npm package in your app [^ts-e2ex-9].

#### How it talks to the device

On both Android and iOS, the CLI installs a small companion driver app on the device. The driver reads what is on screen and does taps and swipes [^ts-e2ex-9]. On iOS the target is an Xcode simulator [^ts-e2ex-10]. This model also controls things outside your app: permission dialogs, Safari, and system settings [^ts-e2ex-9][^ts-e2ex-10]. I did not read the driver source in depth. The repo has the modules `maestro-android`, `maestro-ios-driver`, and `maestro-ios-xctest-runner` [^ts-e2ex-11].

#### A flow with testID, subflow, env, and tags

Main flow `flows/checkout.yaml`:

```yaml
appId: com.example.app
name: Checkout happy path
tags:
  - smoke
  - checkout
env:
  EMAIL: test@example.com
  PASSWORD: secret
onFlowStart:
  - clearState
---
- launchApp
- runFlow:
    file: subflows/login.yaml
- assertVisible:
    id: "home-title"
- tapOn:
    id: "cart-button"
- runFlow:
    when:
      visible:
        id: "promo-banner"
    commands:
      - tapOn:
          id: "promo-close"
- takeScreenshot: cart
- assertVisible: "Total"
```

Subflow `flows/subflows/login.yaml`:

```yaml
appId: com.example.app
---
- tapOn:
    id: "email-input"
- inputText: ${EMAIL}
- tapOn:
    id: "password-input"
- inputText: ${PASSWORD}
- tapOn:
    id: "login-button"
```

I ran `maestro check-syntax` on both files with Maestro 2.12.0. Both printed `OK` and exit code 0. A file with the wrong command `tapOnn` failed with "Invalid Command: tapOnn" [^ts-e2ex-12]. The check is a syntax check only. I did not run the flow on a device, so the selectors are not proven against a real app.

Key points on the features:

- `runFlow` runs a subflow file or an inline command list. It takes `env`, `label`, and a `when` condition [^ts-e2ex-13].
- Variables use the `${NAME}` form. Define defaults in the flow `env` block or pass them with `runFlow` `env` [^ts-e2ex-13]. Set secrets from the CI environment, not in the file.
- Tags go in the flow header. By default, a folder run only takes the top-level flow files. To include subfolders, set the `flows` glob in `config.yaml` [^ts-e2ex-14].
- Subflow files in `flows/subflows/` stay out of the default run for this reason.

#### Studio and Cloud: status from official docs

Maestro Studio is a desktop app. It mirrors the device screen and builds YAML as you click [^ts-e2ex-9][^ts-e2ex-15]. Maestro Cloud is a hosted service. It runs your flows in parallel on hosted virtual devices [^ts-e2ex-15]. The docs list CI guides for GitHub Actions, Bitrise, Bitbucket Pipelines, and CircleCI [^ts-e2ex-16]. Studio and Cloud are products of the Maestro company. Read the vendor page for prices. I did not check them.

### Appium 3 with WebdriverIO

Appium is a server that speaks the WebDriver protocol. Drivers do the device work: UiAutomator2 for Android and XCUITest for iOS [^ts-e2e-3]. Appium 3.9.0 needs Node `^20.19.0 || ^22.12.0 || >=24` [^ts-e2ex-2]. WebdriverIO 10.1.0 needs Node 22.19 or newer [^ts-e2ex-2]. The UiAutomator2 driver lists `appium ^3.0.0-rc.2` as a peer [^ts-e2ex-2]. Appium is black box and has no app sync, so you add explicit waits.

```js
// wdio test with Appium (not run)
import { remote } from 'webdriverio';

const driver = await remote({
  hostname: '127.0.0.1', port: 4723,
  capabilities: {
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:app': './android/app/build/outputs/apk/debug/app-debug.apk',
  },
});
const button = await driver.$('id=login-button');   // resource-id on Android
await button.waitForDisplayed({ timeout: 10000 });
await button.click();
await driver.deleteSession();
```

Note the selector detail. The Android resource-id is the `testID` string, set from RN code (see the selector table below) [^ts-e2ex-18]. WebdriverIO selector strings such as `id=` and `~` come from WebdriverIO conventions. I did not verify them on a device. The UiAutomator2 driver README says the `id` strategy adds the app package prefix when you do not set one [^ts-fc3-3].

Where Appium fits: pick it when you need any language (Java, Python, C#), a device cloud that only offers WebDriver, or one suite for native and web. For a pure RN team, it brings more setup and more flakiness than Maestro or Detox.

### Native frameworks and web

Espresso (Android) and XCUITest (iOS) are the platform frameworks. They run fast and sync with the platform UI. You write two suites in Kotlin or Java and Swift. Few RN teams choose them as the main suite. Detox maps Espresso APIs on Android [^ts-e2ex-22].

For React Native Web, Playwright runs the web build in real browsers [^ts-e2e-4]. It covers only the web target.

### Expo flows

Expo documents Maestro on EAS Workflows. The pattern: a `build` job with a profile that makes an `.apk` or a simulator `.app`, then a `maestro` job with `build_id` and `flow_path` [^ts-e2e-9]. Run the workflow with `eas workflow:run .eas/workflows/e2e-test-android.yml` [^ts-e2e-9]. In other CI systems, build a development or release build, install it, then run `maestro test`.

### Test selectors: from testID to the native id

The `testID` prop is the stable hook for E2E tests. The RN source shows what each platform does with it.

| Layer | What happens | Source |
| --- | --- | --- |
| Shared C++ | `AccessibilityProps` reads the raw prop `testID` into `testId` | `ReactCommon/react/renderer/components/view/AccessibilityProps.cpp:175-176` [^ts-e2ex-18] |
| Android view manager | `setTestId` stores the value as a view tag `R.id.react_test_id` and also as the legacy `view.setTag(testId)` | `BaseViewManager.java:334-340` [^ts-e2ex-18] |
| Android accessibility | The accessibility delegate copies the tag to `info.viewIdResourceName`. This is the `resource-id` that UiAutomator, Appium, and Maestro read | `ReactAccessibilityDelegate.kt:175-181` [^ts-e2ex-18] |
| iOS Fabric view | `RCTViewComponentView` sets `accessibilityIdentifier` on the accessibility element when `testId` changes | `RCTViewComponentView.mm:589-596` [^ts-e2ex-18] |

The Android code comment states the reason. Black box tools use the accessibility framework and cannot read view tags. So RN exposes `testID` as the resource-id and keeps the content description clean [^ts-e2ex-18]. Detox `by.id` and Maestro `id:` both match this value. The Maestro docs say it maps `testID` to `id` [^ts-e2ex-19].

Rules:
- Use `testID` for hooks. Use `accessibilityLabel` and roles when you also test screen reader behavior.
- Text selectors break when copy or language changes.
- Put `testID` on the pressable element, not on a wrapper. A wrapper may merge or hide the child in the accessibility tree.

### Flakiness: causes and fixes

| Cause | Fix |
| --- | --- |
| Animations | Turn them off in the test build. Detox waits for them. An endless loop blocks Detox sync, so disable the loop. |
| Fixed sleeps | Wait on a visible state. Maestro and Detox wait by default. In Appium use explicit waits. |
| Network | Mock the server or use a fixed test backend. Check that network sync sees your HTTP client (see issue 4973) [^ts-e2ex-8]. |
| Shared state | Reset app data per test: `clearState` in Maestro, `newInstance: true` in Detox |
| Cold simulator | Boot and warm the device before the run |
| Debug build with Metro | Test a release-like build in CI. A Metro bundle load adds time and a red box can block the screen. |
| Version drift | Pin RN, the Detox version, and the OS image. Detox reflection on RN internals can break on a minor RN upgrade [^ts-e2ex-8]. |
| Keyboard and system dialogs | Black box tools see system dialogs. Grant permissions in `launchApp` and dismiss dialogs in a conditional `runFlow` [^ts-e2ex-10]. |
| Parallel runs on shared emulators | Give each worker its own device |

Measure flakiness. Re-run the failed test once in CI. Track tests that pass on a re-run, and fix or delete them.

### Visual regression: what exists for RN

| Option | What it does | Status (2026-10-29) |
| --- | --- | --- |
| Maestro `assertScreenshot` | Compares the screen with a stored image inside a flow [^ts-e2ex-20] | Documented in the Maestro command list. Not run. |
| Maestro `takeScreenshot` and Detox `device.takeScreenshot` | Save an image. You compare it yourself or upload it [^ts-e2ex-20][^ts-e2ex-21] | Documented. Not run. |
| Storybook for React Native 10.7.0 | Renders components on device. Gives stable states to shoot [^ts-e2e-5] | Maintained |
| Chromatic | Cloud diff service. Web first. Vendor product [^ts-e2e-6] | Maintained. RN path not verified. |
| Argos | Cloud diff service. Open source CLI [^ts-e2e-6] | Maintained. RN path not verified. |
| react-native-owl | Screenshot tests on device [^ts-e2e-6] | Stale. Last repo push 2025-01-15 [^ts-e2ex-3] |

My advice: capture screenshots from fixed states (Storybook stories or a Maestro flow on a seeded app), run on one pinned device image, and mask dynamic regions. Fonts and OS versions change pixels, so a device change makes a full baseline reset.

### Decision table

The ratings below are my judgment, not measured data.

| Tool | Setup time | Speed | Flakiness risk | Language | CI fit | New Architecture status |
| --- | --- | --- | --- | --- | --- | --- |
| Maestro | Low. Single CLI [^ts-e2ex-9] | Medium | Low | YAML | Good. Free CLI, paid Cloud, guides for four CI systems [^ts-e2ex-16] | Black box. No app code. Docs claim full RN support [^ts-e2ex-19] |
| Detox | High. Native build and config | Fast | Low if sync works. Medium on new RN versions | JS/TS | Good. Needs macOS runners for iOS | Documented to RN 0.84. Not documented for 0.88 [^ts-e2ex-6][^ts-e2ex-8] |
| Appium 3 + WDIO | High. Server, drivers, caps | Slow | Medium. No app sync | Any | Wide. Many device clouds offer it (unverified) | Black box. No impact |
| Espresso / XCUITest | High. Two suites | Fast | Low | Kotlin, Swift | Good | Black box. No impact |
| Playwright | Low | Fast | Low | JS/TS | Good | Web only |

For most RN teams in late 2026, start with Maestro. Choose Detox when you need in-process sync and accept the version risk. Choose Appium when you need other languages or a WebDriver-only cloud.

AI-native test services are not in this table. I could not source every cell, for example flakiness and New Architecture status. See "AI-native test services: Autosana and peers" in Part 4.[^ts-asa-1]

## Part 3: History, device clouds, and CI

Check date: 2026-10-29. Target: React Native 0.88.1 with React 19.3 and the New Architecture only.[^ts-history-1] Dates below come from the npm registry "time" field, GitHub repo metadata, and git history of the RN checkout. Where a date is the first npm publish, the text says so.

### Timeline, 2015 to 2026

| Date | Event | Source |
| --- | --- | --- |
| 2013-01 | Appium repo created. It is the long-running WebDriver based tool for native apps. | [^ts-history-2] |
| 2015-03-05 | Detox name first published on npm at 1.0.0 (an early package). The Wix Detox repo itself was created 2016-06-15. | [^ts-history-3] |
| 2015-03-26 | react-native 0.1.0 on npm. | [^ts-history-4] |
| 2015-12-06 | enzyme 1.0.0 on npm. Its last release, 3.11.0, is from 2019-12-20. | [^ts-history-5] |
| 2016-05-17 | react-test-renderer 1.0.0 on npm. It renders a component tree to plain JS objects without a DOM or a device. | [^ts-history-6] |
| 2016-06-19 | Detox 2.0.0 on npm. This is the start of the gray box E2E tool for RN. | [^ts-history-3] |
| 2016-10-31 | RN adds a Jest preset commit "so that people can configure Jest using react-native as preset". | [^ts-history-7] |
| 2017-01-30 | Cavy 0.0.1 on npm. Cavy is an in-app JS test runner. Last release 4.0.2 on 2021-10-03. Treat it as low activity. | [^ts-history-8] |
| 2017-03-03 | jest-expo first publish on npm. | [^ts-history-9] |
| 2018-10-01 | callstack/react-native-testing-library repo created. First npm publish 2018-10-03. | [^ts-history-10] |
| 2019-04-01 | native-testing-library 1.0.0 on npm. It is now deprecated in favor of @testing-library/react-native (deprecation date not checked). | [^ts-history-11] |
| 2019-05-30 | @testing-library/react-native first publish (4.0.0). | [^ts-history-10] |
| 2020-07-30 | react-native-testing-library 6.0.0 (last release, deprecated) and @testing-library/react-native 7.0.0 on the same day. | [^ts-history-10] |
| 2022-03-31 | Maestro repo (mobile-dev-inc/Maestro) created. | [^ts-history-12] |
| 2024-12-05 | React 19.0.0 stable on npm. react-test-renderer prints a deprecation warning from React 19. | [^ts-history-13] |
| 2024-12-06 | RN adds the @react-native/fantom package (moved to private/ on 2025-06-12 UTC). | [^ts-history-7] |
| 2025-01-03 | @testing-library/react-native 13.0.0. It supports React 18 and 19 (peers: react >=18.2, react-native >=0.71) and drops React 16 and 17. | [^ts-history-10] |
| 2026-02-18 | RN splits the Jest preset into @react-native/jest-preset (first nightly 0.85.0-nightly on 2026-02-19). | [^ts-history-7] |
| 2026-06-05 | @testing-library/react-native 14.0.0. It drops React 18, needs RN 0.78 or newer, and replaces react-test-renderer with test-renderer. Version 14.1.0 is current (2026-10-08). | [^ts-history-10] |
| 2026-10-15 | react-native 0.88.0. Patch 0.88.1 on 2026-10-27. | [^ts-history-4] |

I did not verify these items. Mark them as unchecked in the book: the first Jest use at Facebook for RN, the dates of Frank and Calabash, and the exact EAS Build and jest-expo SDK milestones. The npm "time" field only proves a publish date, not a design decision.

### The eras in plain words

Era 1, 2015 to 2017: unit tests with Jest and shallow renders. Teams used enzyme and react-test-renderer. For device tests they used Appium (WebDriver), and older native tools such as Calabash and Frank.[^ts-history-2] These tools were slow and flaky on JS driven UI. Detox (2016) added a "gray box" model. It knows when the app is idle. That cut flaky waits.[^ts-history-3]

Era 2, 2016 to 2019: snapshot tests. Jest snapshots and react-test-renderer "toJSON" made big snapshot suites. They are cheap to write. They also break on every style change, and teams learn to ignore the diffs. This is an opinion, not a measured result.

Era 3, 2019 to now: user centric tests. Testing Library queries by role, text, and label. The old "native-testing-library" and "react-native-testing-library" packages now point to @testing-library/react-native.[^ts-history-11]

Era 4, 2022 to now: black box YAML flows. Maestro runs flows from a YAML file and needs no app code change.[^ts-history-12] Detox and Appium stay in use.

Era 5, 2024 to now: the React 19 and New Architecture shift. See the next two parts.

### react-test-renderer and React 19

React 19 deprecates react-test-renderer. A warning fires when you call "ReactTestRenderer.create()". The package stays on npm, is not maintained, and "may break with new React features".[^ts-history-14] The npm registry does not flag version 19.3.1 as deprecated (`npm view react-test-renderer@19.3.1 deprecated` is empty). The deprecation is a React warning, not an npm flag. Action: use @testing-library/react-native for new tests. Version 14.1.0 lists "test-renderer ^1.0.0" as a peer dependency and no longer lists react-test-renderer.[^ts-history-15] Version 13.x still lists react-test-renderer as a peer. I did not run a migration.

### Jest preset and Fantom

Until RN 0.84 the preset lived inside the react-native package ("preset: 'react-native'", since a 2016-10-31 commit). Since 2026-02-18 the preset is its own package, @react-native/jest-preset.[^ts-history-7] The RN 0.88.1 checkout has it at packages/jest-preset, and its README says to set "preset: '@react-native/jest-preset'" in jest.config.js.[^ts-history-16] The version on npm for 0.88.x is 0.88.1.[^ts-history-1]

Fantom is the RN team's integration test runner. It runs JS tests against a real native tester build, as Platform.OS android. It is private to the RN repo (private/react-native-fantom), not on npm (E404 on 2026-10-29), and not a tool for app teams.[^ts-history-17] Do not put it in an app test plan.

### What the New Architecture changed for mocks

With the legacy bridge, teams mocked "NativeModules" as a plain object. With TurboModules, a module is loaded through a JS spec. A mock must match the spec name and shape, or the test fails at import time. The RN jest setup mocks core modules, so most app tests run without extra work.[^ts-history-16] Mock third party native modules with "jest.mock('name', factory)" in a setup file. I did not run a TurboModule mock proof for this part. The other parts of the chapter cover that.

### Expo tooling

| Tool | What it does | Status as of 2026-10-29 |
| --- | --- | --- |
| jest-expo | Jest preset for Expo apps. | Version 58.0.13, published 2026-10-28.[^ts-history-9] |
| EAS Build | Cloud native builds. | Vendor docs, in use.[^ts-history-18] |
| EAS Workflows | YAML CI/CD service that runs builds, updates, submissions, and Maestro tests. Files live in ".eas/workflows/". | Docs updated 2026-07-22. Known limits: no shared configs, no matrix builds.[^ts-history-19] |

EAS Workflows runs on Linux workers (linux-medium 4 vCPU, linux-large 8 vCPU), Linux workers with nested virtualization for Android emulators, and macOS workers (macos-medium, macos-large).[^ts-history-19] This is the vendor description.

### Device clouds and CI services, late 2026

Pricing types come from search snippets on 2026-10-29. Only the GitHub and EAS pages were read in full. Rows marked unverified are not proven. Exact prices change often. Check the vendor page before you quote a number.

| Service | What it offers for RN | Pricing model type | Notable limits |
| --- | --- | --- | --- |
| BrowserStack App Automate | Real devices. Appium, Espresso, XCUITest.[^ts-history-20] | Subscription priced per parallel session (third party report). | Parallels are priced one by one. You still write and keep the tests. |
| Sauce Labs | Real and virtual devices. Appium. | Subscription with parallel concurrency (vendor comparison page).[^ts-history-20] | Vendor pages are marketing for comparison. |
| LambdaTest (now branded TestMu AI) | Real device cloud. Appium. | Subscription with parallel tests.[^ts-history-20] | Rename can confuse docs search. |
| AWS Device Farm | Real devices. Appium and native frameworks. | Pay per device minute, with a one time free trial (unverified, search snippet).[^ts-history-21] | No Maestro native flow. You pack the Appium or native tests. |
| Firebase Test Lab | Android devices, iOS devices, Robo test. | Billed by device time with a daily no cost quota (unverified, search snippet).[^ts-history-22] | Google tools fit Android best. |
| Maestro Cloud | Hosted devices for Maestro flows, parallel runs, PR hooks. | Parallel based cloud plans. Maestro itself is open source (unverified, search snippet).[^ts-history-23] | Local runs are free. Cloud cost starts when you need parallel runs or hosted devices. |
| Bitrise | Mobile CI with macOS and Linux stacks. | Credit based plans (not fetched, claim from a comparison page).[^ts-history-24] | I did not read the Bitrise pricing page. Treat as unverified. |
| Codemagic | Mobile CI, M2 and M4 macOS machines. | Pay as you go or fixed plan (unverified, search snippet).[^ts-history-24] | Per minute prices vary by machine type. |
| GitHub Actions | General CI with macOS and Linux runners. | Per minute by runner type. Standard macOS 3 or 4 core is listed at 0.062 USD per minute and Linux 2 core at 0.006 USD per minute on the billing page I fetched today.[^ts-history-25] | macOS minutes cost about 10 times Linux 2-core minutes (0.062 / 0.006). Larger runners are not free for public repos. |
| EAS Workflows | RN specific CI. Builds, updates, Maestro jobs. | Credits and per build charge (unverified, from a search snippet of a vendor blog).[^ts-history-19] | No matrix builds. Best for Expo apps. |

GitHub Actions notes. The macOS runner is the cost driver, so run lint, type check, and unit tests on Linux. Android emulators run on Linux runners with KVM, which avoids macOS cost. iOS simulators need macOS. Cache Gradle, CocoaPods, and the Node package manager. Cache the AVD snapshot if the emulator action supports it. I did not measure cache gains.

### A sensible CI pipeline for an RN app

Order jobs from cheap and fast to slow and costly. Stop early on failure.

| Stage | Runs on | What it checks |
| --- | --- | --- |
| Lint and type check | Linux | ESLint, TypeScript. |
| Unit and component tests | Linux | Jest with the RN preset and Testing Library. |
| Build | Linux (Android), macOS (iOS) | Release build compiles. |
| E2E smoke | Linux emulator, macOS simulator | One to five critical flows (launch, sign in, main screen). |
| Release gate | Any | Manual approval, then store upload (for example EAS or Fastlane). |

Keep the E2E smoke set small. Run the full E2E suite on a nightly schedule or on a device cloud. This is a team choice, not a rule from a source.

Example workflow. The first version of this YAML parsed with js-yaml in Node with three jobs (static, android-e2e, release-gate). The edited version also parsed with PyYAML (same three jobs). I did not run it on GitHub, so treat the emulator and Maestro steps as not run. The Maestro flow file also parsed as two YAML documents (config header and steps).[^ts-history-26]

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 22
          cache: yarn
      - run: yarn install --frozen-lockfile
      - run: yarn lint --max-warnings 0
      - run: yarn tsc --noEmit
      - run: yarn jest --ci --coverage
  android-e2e:
    needs: static
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 22
          cache: yarn
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: 17
      - run: yarn install --frozen-lockfile
      - run: cd android && ./gradlew assembleRelease
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - run: curl -Ls https://get.maestro.mobile.dev | bash
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          arch: x86_64
          script: |
            adb install android/app/build/outputs/apk/release/app-release.apk
            $HOME/.maestro/bin/maestro test .maestro/smoke.yaml
  release-gate:
    needs: [static, android-e2e]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: echo "Approval gate. Run eas build and submit here."
```

The emulator runner README (checked 2026-10-29) says to enable KVM first and to prefer Ubuntu runners. It runs each line of `script` as a separate shell command, so an `export PATH` on one line does not carry to the next. The sample uses the full path to avoid this. Action versions (checkout 7.0.1, setup-node 7.1.0, setup-java 6.1.0, emulator-runner 2.38.0) are the latest GitHub releases on 2026-10-29.[^ts-history-26] The edited YAML was not re-run on GitHub. The first version of this sample had `v4` action tags and the `export PATH` line.

## Part 4: Agentic AI and testing

This section is about what exists on 2026-10-29, not about what vendors promise. Each tool below has a checked version, license, and date.[^ts-ai-1] A coding agent is a language model that reads files, runs commands, and calls tools. A tool server speaks the Model Context Protocol (MCP) and lets the agent touch a device.

### What changes and what does not

Agents change who writes and runs tests. They do not change what a good test is. A test must fail when the app is wrong and pass when the app is right. An agent can write a test that always passes. So the human still owns the oracle, the rule that says what "right" means.

### MCP servers for devices and simulators

An MCP server turns a simulator or emulator into a set of tools. Most servers expose the same four things: a screenshot, a view tree, input (tap, type, swipe), and logs. The table compares the servers I checked.

| Server | What it exposes | License | Status on 2026-10-29 |
| --- | --- | --- | --- |
| mobile-mcp (mobile-next) | Screenshot, element list with refs, tap, type, swipe, app install and launch, device logs, crash reports, screen recording, remote device cloud tools. 34 tools listed by two runs.[^ts-ai-2] | Apache-2.0 | npm 1.0.14, released 2026-10-26. Last commit 2026-10-26. About 10k GitHub stars (project data, not a quality signal).[^ts-ai-3] |
| appium-mcp (Appium project) | Appium session, find element, gesture, page source, screenshot, screen recording, locator generation, test code generation. 32 tools listed by my run. A vision-based find tool exists only when `AI_VISION_ENABLED=true`.[^ts-ai-4] | Apache-2.0 | npm 1.99.1, released 2026-10-27. Needs Node 22 or later. The README says it is for a local single-user server or a trusted CI job.[^ts-ai-4] |
| Maestro MCP | Inside the Maestro CLI (`maestro mcp`). Tools: `list_devices`, `inspect_screen`, `take_screenshot`, `run` (inline YAML), `cheat_sheet`, cloud run tools, `open_maestro_viewer`.[^ts-ai-5] | Apache-2.0 (Maestro repo) | Maestro CLI 2.12.0, released 2026-10-26.[^ts-ai-3] |
| Expo MCP | Remote server `https://mcp.expo.dev/mcp` (OAuth, Expo account needed). The docs table lists more than 40 server tools for docs search, EAS builds and workflows, EAS Observe, store reviews and crash data. Some tools bill EAS minutes. Local tools need the `expo-mcp` dev package and `EXPO_UNSTABLE_MCP_SERVER=1`: screenshot, tap by `testID`, find view by `testID` or label, open DevTools, collect logs, router sitemap.[^ts-ai-6] | MIT (`expo-mcp` package) | npm `expo-mcp` latest 0.2.4 (2026-02-12). The `next` tag is 0.3.1 (2026-06-26). The repo has 9 stars and its last push was 2026-07-29. The env flag name contains UNSTABLE. Local features need SDK 54 or later. iOS is simulator only.[^ts-ai-6] |
| XcodeBuildMCP (now MobileBuildMCP, Sentry) | Build, test, and run for iOS and macOS projects. Also a CLI. 24 tools listed by my run with no project config: session defaults, simulator build, run, test, install, launch, screenshot, UI snapshot, coverage.[^ts-ai-7] | MIT | The npm package is now `mobilebuildmcp` 2.7.1 (2026-09-23). The old name `xcodebuildmcp` stopped at 2.7.0 on 2026-07-23. Last commit 2026-10-22. Needs macOS 14.5 and Xcode 16 or later. It builds native projects. It does not drive an RN-specific layer.[^ts-ai-7] |
| ios-simulator-mcp (joshuayoes) | iOS simulator control: describe screen, tap, type, swipe, screenshot, video, install, launch. 17 tools listed by my run. Community project, not from Apple. Its README uses Facebook idb.[^ts-ai-3] | MIT | npm 2.2.0, released 2026-10-27. Last commit 2026-10-27.[^ts-ai-3] |

Notes on the table:

- Expo MCP is not a bare React Native tool. It needs an Expo project. A bare React Native app should use mobile-mcp, Maestro MCP, or appium-mcp.
- Expo docs say the capability list "may not be up to date".[^ts-ai-6] Read the live tool list from your own install.
- Community servers for React Native DevTools and Metro exist (for example `pnarayanaswamy/react-native-devtools-mcp`). I found them by web search and did not install or vet them. Treat them as unreviewed.[^ts-ai-8]
- Do not confuse `@mobilenext/mobile-mcp` with the npm package `mobile-mcp`. The second one is a different project (version 0.0.7, last change 2025-04-02). My first run used it by mistake.[^ts-ai-2]

### Accessibility tree or screenshot

An agent can read the screen in two ways. Each way has a cost.

| Input | Strength | Weakness |
| --- | --- | --- |
| Accessibility tree (text) | Cheap in tokens. Exact labels. Stable refs. Works without a vision model. | Shows only what the app exposes. Custom-drawn views are missing. |
| Screenshot (image) | Shows layout, color, clipping, overlap. | Costs more tokens. The model can misread small text. Coordinates can drift. |

The tool descriptions confirm the design. The mobile-mcp element tool returns "ref, coordinates, and display text or accessibility label" and its click tool accepts a ref such as `@e5`.[^ts-ai-2] The Maestro tool `inspect_screen` returns the view hierarchy as compact JSON and tells the agent to call it again after each UI change.[^ts-ai-5] Appium MCP turns vision lookup off by default so the model does not use a slow paid call when a stable locator works.[^ts-ai-4]

### Why testID and accessibility labels matter more now

A human tester sees a blue button. An agent sees a tree. If the tree has no names, the agent guesses with pixel coordinates. Coordinates break when the layout changes.

- Expo's own tool text says to prefer `testID` "as it is resilient to layout changes".[^ts-ai-6]
- Expo `automation_find_view` finds a view by `testID` or accessibility label.[^ts-ai-6]
- The same labels help screen reader users. One fix serves both.

Rules for a team:

1. Give each interactive element an `accessibilityLabel` that a user would hear. Add `testID` for elements that have no good label.
2. Keep `testID` values stable and unique per screen.
3. Do not put a secret or a user name in a label. An agent log can copy it.

### Agents that write tests

| Kind | Example | How it fits |
| --- | --- | --- |
| Unit and component tests | Coding agent writes Jest and React Native Testing Library tests | Fast. Run in CI with no model. The agent can run the test and fix the error. |
| End-to-end flows | Agent writes Maestro YAML through the `run` tool and keeps the working flow | The agent proves the flow on a device before you commit it.[^ts-ai-5] |
| AI steps inside a flow | Maestro `assertWithAI` | Sends a screenshot to an LLM and gets true or false. Marked experimental. `optional` is `true` by default, so a failed AI check does not stop the run.[^ts-ai-9] |
| Self-healing locators | BrowserStack Self-Healing Agent for Appium on App Automate | Vendor feature (marketing page, docs page fetched). It needs BrowserStack AI enabled on the account and the App Automate Pro plan. Set the `selfHeal` capability. It heals `findElement` calls. `findElements` healing is Beta. It needs one earlier passing run with the same locator. It can misfire on negative assertions.[^ts-ai-10] |

The agent output is code. Review it like code. Check that each test asserts a user-visible result. Delete tests that only check that a mock was called.

### Agents that run the app

Two styles exist.

- Tree-driven agent: reads the accessibility tree, picks a ref, taps. This is the mobile-mcp, Maestro MCP, and Expo MCP style.
- Vision or computer-use agent: reads pixels and clicks coordinates. It works on any UI. It is slower and less repeatable. Appium MCP offers this as an opt-in tool with a vision API key.[^ts-ai-4]

Use the tree-driven style first. Use vision only when the tree has a gap.

### Cloud services: what exists

I checked vendor docs only. I did not run these services. Every claim here is a vendor claim.

| Vendor | Documented feature | Label |
| --- | --- | --- |
| BrowserStack | Self-Healing Agent for Appium on App Automate. Needs account-level AI setting and the Pro plan. Docs page fetched 2026-10-29, not run by me.[^ts-ai-10] | Vendor docs, marketing |
| Maestro Cloud | `run_on_cloud` and `get_cloud_run_status` MCP tools. Needs `maestro login` or `MAESTRO_CLOUD_API_KEY`.[^ts-ai-5] | Vendor docs |
| LambdaTest (now TestMu AI) | KaneAI: you write steps in plain English and it makes app tests for Android and iOS. Docs page fetched, last updated 2026-09-11. The page has no claim about React Native.[^ts-ai-11] | Vendor docs, marketing. Not run by me. |
| Waldo | No-code mobile testing. Tricentis announced the purchase in a blog post dated 2023-07-07. The post says it adds Waldo to the Tricentis mobile testing offerings.[^ts-ai-12] | Fact from the acquirer's blog |
| Sauce Labs | Not checked in this pass. | Do not cite until verified |
| mabl, QA Wolf, Autosana, Revyl, MobileBoost | See the next subsection. | Vendor docs and pages |

Percent figures such as "70% less maintenance" appear in vendor marketing. I did not repeat any because I found no independent measurement.

### AI-native test services: Autosana and peers

An AI-native test service runs an agent that reads the screen and follows a plain-language flow. You do not write selectors. This subsection covers Autosana and six peers. I read vendor pages and docs on 2026-10-29. I did not sign up. I did not run any service. Every product claim below is a vendor claim unless the text says otherwise.

#### Autosana

- What it is: a hosted end-to-end test platform for iOS, Android, and web. Y Combinator lists it as Summer 2025 batch, founded 2025, team size 5, two founders.[^ts-asa-1]
- How you write tests: natural language. A flow is a YAML file (`*.flow.yaml`) with `name` and `instructions`. Docs list a `.autosana/` folder in your repo, synced from GitHub.[^ts-asa-2]
- Element finding: the founders say it is "fully vision based".[^ts-asa-1] The docs say "No Selectors" and "Self-Healing".[^ts-asa-3] I found no public detail on how the agent resolves elements.
- Where it runs: cloud iOS Simulators and Android Emulators. Real Android devices take an `.apk`. The iOS `.app` build is simulator only. Real iPhones are on the Pro plan (5 sessions).[^ts-asa-4][^ts-asa-5]
- React Native and Expo: the docs give steps. Build in Release mode, because a Debug build looks for Metro. For Expo, use an EAS profile with `simulator: true`.[^ts-asa-4] The docs do not name a React Native version.
- CI and agents: a CLI (`autosana run`, `autosana flows validate`), a GitHub bot, a GitHub Action for build upload, and an MCP server at `https://mcp.autosana.ai/mcp`.[^ts-asa-6][^ts-asa-7]
- Cost: pay as you go at $0.10 per AI action and $0.01 per cached action, with 1,000 free actions each month. Startup is $999 per month. Pro is $2,499 per month. Prices were on the page on 2026-10-29.[^ts-asa-5]
- Lock-in: the flow files are plain YAML in your repo, and `autosana flows export` writes them. I found no export to Maestro or to code. The CLI on PyPI has license "Proprietary".[^ts-asa-2][^ts-asa-8]
- Maturity: the product page lists customer logos and quotes. These are vendor claims. I found no funding amount. The security page only gives a disclosure address. The footer says SOC 2 Type 1, with Type 2 "in review". I found no data retention policy for screenshots or uploaded builds.[^ts-asa-9]

I ran the public CLI in `tmp/refresh/testing/scratch/autosana/`. `uv pip install autosana` gave version 0.18.1. The help output lists `login`, `run`, `flows`, `builds`, `keys`, and `devices`. This proves the CLI exists. It does not prove the cloud agent works.[^ts-asa-8]

#### Peers

| Service | How you write tests | Runs on | Pricing model | Status seen on 2026-10-29 |
| --- | --- | --- | --- | --- |
| Autosana | Natural language flows, YAML in repo | Cloud simulators, emulators, real devices on Pro | Per AI action, plus monthly plans | YC S25, product updates to 2026-09-21[^ts-asa-5][^ts-asa-10] |
| Revyl | Natural language and CLI (`revyl run`) | Cloud iOS and Android simulators | Free tier, $250 per month Starter, per-minute overage | Pricing page live, SOC 2 Type II badge (vendor)[^ts-asa-11] |
| MobileBoost GPT Driver | Natural language, or AI inside Appium, XCUITest, Espresso | Simulators and real devices | Quote only on the site. A rival's page says $799 per month (secondhand) | Site live, YC backed (vendor)[^ts-asa-12] |
| QA Wolf | Managed service and a self-serve platform | Vendor cloud | $2 per mobile run (vendor) | Pricing model changed in 2026[^ts-asa-13] |
| mabl | Low-code and AI agents | Cloud, mobile and browser | Credit based (secondhand: about $450 per month) | Site live[^ts-asa-14] |
| Maestro with `assertWithAI` | YAML plus an experimental AI step | Local, or Maestro Cloud | Free CLI, paid cloud | `assertWithAI` is "experimental"[^ts-ai-9] |
| Waldo | No-code | Cloud | Not checked | Tricentis bought it in 2023. I did not check current status[^ts-ai-12] |

KaneAI from LambdaTest (now TestMu AI) is in the earlier table.[^ts-ai-11]

#### When to choose it and when not

Choose an AI-native service when:
- the team has no one to own a Maestro or Detox suite
- flows are hard to script (OTP, push, in-app purchase, Apple Pay)
- you want a video on each pull request, and a coding agent can call it by MCP

Do not choose it when:
- the app must not leave your network, and the vendor offers no private path you can verify
- you need a fixed, cheap gate on every commit
- you need a free, forkable test format

#### Honest limits

- Test oracle: the agent reads the screen and decides pass or fail. A person must write the expected result in the flow. A vague step such as "check it looks right" is a weak oracle.
- Determinism: the same flow can take a different path. Autosana says it replays passing flows from a cache, 5 to 8 times faster (vendor claim). A cache hides drift until a UI change.[^ts-asa-3]
- Flakiness: self-healing can pass a test after the UI broke. I found no independent measurement of its false pass rate.
- Cost: you pay per action or per minute. A long flow on every pull request adds up.
- Data: a build upload and screenshots go to the vendor cloud. Use test accounts only. Read the data processing terms first.

For a book reader, the first check is the oracle. Run one flow with a known bug and see if it fails.

### Risks

| Risk | What happens | Control |
| --- | --- | --- |
| Flaky, non-deterministic tests | The same prompt gives a different path on each run | Agents explore. CI replays fixed scripts. |
| Cost | Each step sends a tree or an image. Long sessions cost many tokens | Prefer the tree. Use `NO_UI=true` in Appium MCP to cut tokens (project claim).[^ts-ai-4] |
| Secrets in screenshots | A screenshot can show tokens, emails, and test card numbers. Expo says screenshots pass through its server, then to your model provider.[^ts-ai-6] | Use fake accounts and seed data. Read the provider retention policy. |
| Prompt injection through app text | Text in the UI, a push, or a web view can contain "ignore your rules". The agent reads it as input | Run on a clean device with a test backend. Give the agent no production credentials. Ask for confirmation on destructive tools. |
| Test oracle problem | The agent decides pass or fail from its own reading of the screen | The human writes the expected result first. |
| Review burden | A fast agent makes many tests. A person must read them | Small pull requests. One flow per pull request. |
| Server trust | appium-mcp says do not expose it to untrusted users, and do not build `remoteServerUrl` from pull request content in CI.[^ts-ai-4] | Keep MCP config in trusted files. |

### A practical workflow

A team uses a coding agent with one simulator MCP to build a feature. The steps:

1. Write the spec in plain words, with the expected result of each step.
2. Start Metro and the simulator. Connect the MCP server (for example `claude mcp add maestro -- maestro mcp`).[^ts-ai-5]
3. Ask the agent to add `testID` and labels as it writes the screen.
4. Ask the agent to run the flow on the simulator. It reads the tree, taps, and takes a screenshot.
5. A human looks at the screenshot and the tree. This is the oracle step.
6. Ask the agent to save the passing flow as a Maestro YAML file, and add Jest and RNTL tests for the logic.
7. Commit the files. Review them as code.

What must stay deterministic in CI:

- Jest unit and component tests with no network and no model.
- Maestro or Detox flows as fixed files. The CI job replays them. It does not ask a model what to do.
- A fixed simulator image, a fixed app build, and seeded test data.
- No `assertWithAI` in the gate, unless you set `optional: false` and accept the flake rate.[^ts-ai-9]

AI belongs outside the gate: drafting tests, exploring a new screen, triaging a failure. The gate stays plain code.

### New Architecture note

These tools drive the app from outside: through the accessibility layer, `adb`, or `simctl`. They do not call the old bridge. So the New Architecture does not break them in principle. I did not run any of them against an RN 0.88 app. That check is open.

---

## Footnotes

[^ts-unit-1]: `npm view react-native dist-tags`: latest 0.88.1, published 2026-10-27. `npm view react dist-tags` and react-test-renderer 19.3.1. Checked 2026-10-29.
[^ts-unit-2]: Tarball `react-native@0.84.0` (npm registry) contains `package/jest/` and `package/jest-preset.js`. Listed with `tar tzf`, 2026-10-29.
[^ts-unit-3]: `react-native@0.85.0` tarball, `package/jest-preset.js` lines 12-24 (stub that requires `@react-native/jest-preset` and throws a migration message). Same text in RN repo history. Checked 2026-10-29.
[^ts-unit-4]: `npm view @react-native/jest-preset time --json`: created 2026-02-19, first 0.85.0-rc.0 on 2026-03-03, 0.88.1 on 2026-10-27. Checked 2026-10-29.
[^ts-unit-5]: /Users/gaston/Projects/tesla/react-native/packages/jest-preset/package.json (engines node >= 22.13.0, peerDependencies react ^19.2.3, dependencies babel-jest ^29.7.0, jest-environment-node ^29.7.0).
[^ts-unit-6]: packages/jest-preset/jest-preset.js (haste, resolver, transform, transformIgnorePatterns, setupFiles, testEnvironment).
[^ts-unit-7]: packages/jest-preset/jest/setup.js, the `mock(...)` calls (about lines 90-210).
[^ts-unit-8]: `npm view jest version time.modified`: 30.5.2, modified 2026-09-18. Checked 2026-10-29.
[^ts-unit-9]: Scratch proof: tmp/refresh/testing/scratch/unit/proof-unit-jest.txt and proof-unit-jest2.txt (Jest 30.5.2, RN 0.88.1, RNTL 14.1.0, React 19.3.1, 3 tests passed). Install used `--before=2026-10-30` because the local npm has a 14-day release-age rule.
[^ts-unit-10]: `npm view @testing-library/react-native version time.modified peerDependencies`: 14.1.0, 2026-10-08; peers jest >=29, react >=19, react-native >=0.78, test-renderer ^1.0.0. Checked 2026-10-29.
[^ts-unit-11]: `node_modules/@testing-library/react-native/dist/render.d.ts:16` and `render-hook.d.ts:19` declare `Promise` return types (RNTL 14.1.0, scratch install).
[^ts-unit-12]: https://github.com/callstack/react-native-testing-library/releases/tag/v14.0.0 (breaking changes: "Replaced the deprecated React Test Renderer with Test Renderer", "Added a peer dependency on Test Renderer 1.x"). `npm view test-renderer`: npm package created 2026-01-07, latest 1.3.1, repo github.com/mdjastrzebski/test-renderer (GitHub repo created 2024-11-01). Its README calls it "a modern replacement for the deprecated React Test Renderer". Checked 2026-10-29. Proof: tmp/refresh/testing/scratch/FC-1/npm3.txt.
[^ts-unit-13]: https://react.dev/warnings/react-test-renderer (fetched 2026-10-29): "react-test-renderer is deprecated ... will remain available on NPM but will not be maintained and may break with new React features or changes to React's internals."
[^ts-unit-14]: https://callstack.github.io/react-native-testing-library/docs/api/events/user-event (vendor docs, not re-fetched; claim about full event sequence is from the docs summary, treat as Assumed).
[^ts-unit-15]: `npm view @testing-library/jest-native deprecated`: "no longer maintained, use the built-in Jest matchers in @testing-library/react-native v12.4+". Checked 2026-10-29.
[^ts-unit-16]: `npm view msw version time.modified`: 3.0.3, 2026-10-10. Checked 2026-10-29.
[^ts-unit-17]: Opinion. Testing Library guiding principles: https://testing-library.com/docs/guiding-principles (not re-fetched, Assumed).
[^ts-unit-18]: /Users/gaston/Projects/tesla/react-native/package.json:46 (`"test": "jest"`).
[^ts-unit-19]: private/react-native-fantom/__docs__/README.md lines 1-60 and 68-110 (warning block, definition, usage, `yarn fantom`). Root package.json:47.
[^ts-unit-20]: packages/rn-tester/README.md line 3 ("The RNTester showcases React Native views and modules").
[^ts-e2e-1]: npm view detox version time (2026-10-29), https://api.github.com/repos/wix/Detox (pushed_at 2026-10-28) and /releases (20.51.3, 2026-05-30).
[^ts-e2e-2]: https://github.com/mobile-dev-inc/maestro releases, tag cli-2.12.0, published 2026-10-26. Local run in scratch/e2e/proof-maestro.txt.
[^ts-e2e-3]: npm view appium, appium-uiautomator2-driver, appium-xcuitest-driver version time (2026-10-29). https://github.com/appium/appium
[^ts-e2e-4]: npm view playwright version, https://github.com/microsoft/playwright/releases/tag/v1.64.1
[^ts-e2e-5]: npm view @storybook/react-native version, https://github.com/storybookjs/react-native/releases/tag/v10.7.0
[^ts-e2e-6]: npm view chromatic, @argos-ci/cli, react-native-owl version time (2026-10-29).
[^ts-e2e-7]: npm view detox peerDependencies --json (2026-10-29).
[^ts-e2e-8]: https://raw.githubusercontent.com/wix/Detox/master/README.md, line "RN v0.77.x - v0.84.x: Fully compatible with the New Architecture".
[^ts-e2e-9]: https://docs.expo.dev/eas/workflows/examples/e2e-tests/ (last updated 2026-07-22).
[^ts-history-1]: `npm view react-native@0.88.1 peerDependencies` (react ^19.3.0) and `npm view @react-native/jest-preset time`, checked 2026-10-29. Proof: scratch/history/proof-npm.txt.
[^ts-history-2]: Appium repo created 2013-01-09, last push 2026-10-28, not archived. GitHub API https://api.github.com/repos/appium/appium, checked 2026-10-29. npm appium 3.9.0 on 2026-10-27. Calabash and Frank dates: not verified.
[^ts-history-3]: `npm view detox time`: 1.0.0 2015-03-05, 2.0.0 2016-06-19. Repo wix/Detox created 2016-06-15, last push 2026-10-28 (GitHub API). Detox 20.51.4 current.
[^ts-history-4]: `npm view react-native time`: 0.1.0 2015-03-26, 0.88.0 2026-10-15, 0.88.1 2026-10-27.
[^ts-history-5]: `npm view enzyme time`: 1.0.0 2015-12-06, 3.11.0 2019-12-20. The earlier claim about adapters for React 18 or 19 was removed (not proven).
[^ts-history-6]: `npm view react-test-renderer time`: 1.0.0 2016-05-17.
[^ts-history-7]: RN git history, commands run in the checkout: `git log --diff-filter=A` on packages/jest-preset/package.json (c4ae05534ad, 2026-02-18, "Split out Jest preset to @react-native/jest-preset (#55169)"), on packages/react-native-fantom/package.json (b253b0fe945, 2024-12-06), `git log` on jest-preset.json (6d3e074dd45, 2016-10-31), and d6f29c8afd1 (2025-06-11, move to private). Commit 714b502b0c7 (2023-03-17, "RN Monorepo | Migrate to package") is a monorepo move, not a Jest change. The chapter no longer claims it. The 2025-06 Fantom move is d6f29c8afd1, authored 2025-06-12T06:49Z (GitHub API).
[^ts-history-8]: `npm view cavy time`: 0.0.1 2017-01-30, 4.0.2 2021-10-03.
[^ts-history-9]: `npm view jest-expo time version`: first 0.3.0-beta.0 2017-03-03, 58.0.13 on 2026-10-28.
[^ts-history-10]: `npm view @testing-library/react-native time` and `npm view react-native-testing-library time` (6.0.0 2020-07-30, deprecated). Repo callstack/react-native-testing-library created 2018-10-01, last push 2026-10-20.
[^ts-history-11]: `npm view native-testing-library deprecated`: "has moved to @testing-library/react-native". 1.0.0 2019-04-01, 4.0.0 2019-05-31. See https://github.com/testing-library/dom-testing-library/issues/260.
[^ts-history-12]: Repo mobile-dev-inc/Maestro created 2022-03-31, last push 2026-10-28, not archived. Release cli-2.12.0 on 2026-10-26 (GitHub API).
[^ts-history-13]: `npm view react time`: 19.0.0 on 2024-12-05.
[^ts-history-14]: https://react.dev/warnings/react-test-renderer (fetched in full 2026-10-29). `npm view react-test-renderer@19.3.1 deprecated`: empty. Proof: tmp/refresh/testing/scratch/FC-1/npm2.txt.
[^ts-history-15]: `npm view @testing-library/react-native@14.1.0 peerDependencies`: jest >=29, react >=19, react-native >=0.78, test-renderer ^1.0.0.
[^ts-history-16]: packages/jest-preset/README.md:30-38 and package.json (name, engines node >= 22.13.0) in the RN checkout. The checkout package.json says version 0.87.0-main while npm has 0.88.1, so the local file is older than the tag.
[^ts-history-17]: private/react-native-fantom exists in the checkout. `npm view @react-native/fantom` returns E404. Platform.OS android claim: AGENTS.md of the repo.
[^ts-history-18]: https://docs.expo.dev/eas/ (not fetched in detail). Date of first EAS Build not verified.
[^ts-history-19]: https://docs.expo.dev/eas/workflows/introduction/ fetched 2026-10-29 (page dated 2026-07-22). Pricing per build: https://expo.dev/blog/best-ci-cd-for-mobile-apps (search snippet, vendor blog).
[^ts-history-20]: Search snippets only: https://bug0.com/knowledge-base/browserstack-app-automate and https://saucelabs.com/resources/blog/browserstack-vs-testmu-ai-formerly-lambdatest-vs-sauce-labs-which-cloud-testing-grid-fits-your-team. Third party and vendor sources. Vendor pages not fetched.
[^ts-history-21]: https://aws.amazon.com/device-farm/pricing/ (search snippet 2026-10-29: pay for what you use, one time free trial).
[^ts-history-22]: https://firebase.google.com/docs/test-lab/usage-quotas-pricing (search snippet 2026-10-29: billing by minutes, daily no cost limit on Blaze).
[^ts-history-23]: https://maestro.dev/pricing (search snippet 2026-10-29: free open source, Maestro Cloud for parallel execution).
[^ts-history-24]: https://codemagic.io/pricing/ and https://docs.codemagic.io/billing/pricing/ (search snippets 2026-10-29). Bitrise: only a Codemagic comparison page and a third party snippet.
[^ts-history-25]: https://docs.github.com/en/billing/reference/actions-runner-pricing fetched 2026-10-29.
[^ts-history-26]: scratch/history/proof-yaml.txt, ci.yml and smoke.yaml, parsed with js-yaml via Node. Edited YAML re-parsed with PyYAML: tmp/refresh/testing/scratch/FC-1/ci.yml. Action versions from `https://api.github.com/repos/<repo>/releases/latest` on 2026-10-29: actions/checkout v7.0.1, actions/setup-node v7.1.0, actions/setup-java v6.1.0, ReactiveCircus/android-emulator-runner v2.38.0. Emulator runner README: https://github.com/ReactiveCircus/android-emulator-runner
[^ts-ai-1]: Checked 2026-10-29 with `npm view <pkg> version license time.modified` and the GitHub API. Output saved in `tmp/refresh/testing/scratch/ai/proof-repos.txt`.
[^ts-ai-2]: Run on 2026-10-29: `@mobilenext/mobile-mcp` started over stdio, `tools/list` returned 34 tools. The first run (`scratch/ai/proof-mobile-mcp-tools.txt`) printed banner 1.0.11 and sdk 2.0.0, so it ran an older cached copy and not 1.0.14. A clean install with `--before` (`scratch/FC-2/mm`, `mm-tools.txt`) printed banner 1.0.14 and sdk 2.4.0, and also listed 34 tools. Only two tool descriptions differ (`get_more_tools`, `mobile_get_foreground_app`). The banner reads the version from package.json (`lib/server.js` `getAgentVersion`). The wrong package run (`mobile-mcp` 0.0.7, 9 tools) is in `proof-WRONGPKG-runablehq-mobile-mcp.txt`.
[^ts-ai-3]: GitHub API and npm registry, checked 2026-10-29: mobile-next/mobile-mcp release 1.0.14 (2026-10-26), Apache-2.0. mobile-dev-inc/Maestro release cli-2.12.0 (2026-10-26), Apache-2.0. joshuayoes/ios-simulator-mcp v2.2.0 (2026-10-27), MIT. See `proof-repos.txt`.
[^ts-ai-4]: https://github.com/appium/appium-mcp README (fetched 2026-10-29). npm `appium-mcp` 1.99.1, Apache-2.0, last commit 2026-10-27. Run of `tools/list` on an installed 1.99.1 gave 32 tools: `scratch/FC-2/am/appium-tools.txt`. README sections on `AI_VISION_ENABLED`, `NO_UI` and the remote server trust model confirm the claims.
[^ts-ai-5]: https://docs.maestro.dev/get-started/maestro-mcp (fetched 2026-10-29, "Last updated 3 days ago").
[^ts-ai-6]: https://docs.expo.dev/mcp/ (fetched again 2026-10-29, last updated 2026-10-28). The page says new projects use the SDK 58 template. npm `expo-mcp` dist-tags: latest 0.2.4, next 0.3.1. MIT. Repo https://github.com/expo/expo-mcp, last push 2026-07-29, 9 stars. I did not connect to the remote server (OAuth).
[^ts-ai-7]: https://github.com/getsentry/XcodeBuildMCP README (redirects to getsentry/MobileBuildMCP), npm `mobilebuildmcp` 2.7.1 (2026-09-23), MIT, checked 2026-10-29. Last commit 2026-10-22. Installed 2.7.1 and ran `mobilebuildmcp mcp`: 24 tools, log `Server initialized (version 2.7.1)`. Files: `scratch/FC-2/mb-tools.txt`.
[^ts-ai-8]: Web search result, 2026-10-29: https://github.com/pnarayanaswamy/react-native-devtools-mcp. Not installed. Not vetted.
[^ts-ai-9]: https://docs.maestro.dev/reference/commands-available/assertwithai (fetched 2026-10-29).
[^ts-ai-10]: https://www.browserstack.com/docs/app-automate/appium/self-healing (fetched 2026-10-29). The page says AI must be enabled on the account and that Self-Heal is available only on the App Automate Pro plan. `findElements` healing is marked Beta.
[^ts-ai-11]: https://www.testmuai.com/support/docs/kane-ai-app-test/ (fetched 2026-10-29, last updated 2026-09-11).
[^ts-ai-12]: https://www.tricentis.com/blog/tricentis-acquires-waldo-no-code-mobile-test-automation-platform (fetched 2026-10-29, dated Jul. 07, 2023).
[^ts-e2ex-1]: wix/Detox repo HEAD fc34e84, commit date Tue 2026-10-27 22:17 +0200 (git log, clone in tmp/testing-repos/Detox, checked 2026-10-29). Version in detox/package.json: 20.51.4.
[^ts-e2ex-2]: npm view webdriverio, appium, appium-uiautomator2-driver version time engines peerDependencies (2026-10-29). Saved in scratch/e2e/deep/proof-deep-npm.txt.
[^ts-e2ex-3]: gh api repos/FormidableLabs/react-native-owl: pushed_at 2025-01-15T16:33:42Z, archived false (2026-10-29).
[^ts-e2ex-4]: Detox docs/articles/how-detox-works.md (sections "Automatic App-State Synchronization", "Operations Detox synchronizes with automatically") and docs/articles/design-principles.md:9, repo HEAD fc34e84.
[^ts-e2ex-5]: Detox examples/demo-react-native/detox.config.js, repo HEAD fc34e84 (apps, devices, iosCIBuildSettings for RN 0.85).
[^ts-e2ex-6]: Detox README.md:66-67, repo HEAD fc34e84.
[^ts-e2ex-7]: Detox detox/package.json:85 `"react-native": "0.85.2"`, repo HEAD fc34e84.
[^ts-e2ex-8]: https://github.com/wix/Detox/issues/4963 (opened 2026-07-02, updated 2026-09-03, open) and /issues/4973 (open), read with gh issue list/view on 2026-10-29. Search for RN 0.86 to 0.88 returned no matching Detox issue or release note. Releases: gh release list -R wix/Detox, latest 20.51.3 on 2026-05-30.
[^ts-e2ex-9]: https://docs.maestro.dev/get-started/how-maestro-works.md and https://docs.maestro.dev/get-started/what-is-maestro.md (read 2026-10-29).
[^ts-e2ex-10]: https://docs.maestro.dev/get-started/supported-platform/ios.md (read 2026-10-29): Xcode simulators, permissions, multi-app journeys.
[^ts-e2ex-11]: mobile-dev-inc/maestro repo root at HEAD (commit date 2026-10-28): modules maestro-android, maestro-ios-driver, maestro-ios-xctest-runner.
[^ts-e2ex-12]: scratch/e2e/deep/proof-deep-checksyntax.txt. Files flows/checkout.yaml and flows/subflows/login.yaml, Maestro 2.12.0, Java 21.
[^ts-e2ex-13]: https://docs.maestro.dev/reference/commands-available/runflow.md (parameters label, env; inline commands with a when condition).
[^ts-e2ex-14]: https://docs.maestro.dev/maestro-flows/workspace-management/test-discovery-and-tags.md (top-level only by default, `flows` globs in config.yaml, tags metadata).
[^ts-e2ex-15]: https://docs.maestro.dev/get-started/maestro-solutions.md and https://docs.maestro.dev/maestro-studio/maestro-studio-overview.md (read 2026-10-29).
[^ts-e2ex-16]: https://docs.maestro.dev/llms.txt, Maestro Cloud CI/CD pages: GitHub Actions, Bitrise, Bitbucket Pipelines, CircleCI.
[^ts-e2ex-18]: RN checkout at main 9c7b0f5fafd: packages/react-native/ReactCommon/react/renderer/components/view/AccessibilityProps.cpp:175-176; ReactAndroid/src/main/java/com/facebook/react/uimanager/BaseViewManager.java:334-340; ReactAndroid/src/main/java/com/facebook/react/uimanager/ReactAccessibilityDelegate.kt:175-181; React/Fabric/Mounting/ComponentViews/View/RCTViewComponentView.mm:589-596.
[^ts-e2ex-19]: https://docs.maestro.dev/get-started/supported-platform/react-native.md ("the best practice is to use the testID property, which Maestro maps to a unique id").
[^ts-e2ex-20]: https://docs.maestro.dev/llms.txt entries for assertScreenshot and takeScreenshot (read 2026-10-29). Not run.
[^ts-e2ex-21]: Detox docs/api/device.md:517 `device.takeScreenshot([name])`, repo HEAD fc34e84.
[^ts-e2ex-22]: Detox docs/architecture/client-server.md:146 (Android espressoapi generation) and :152.
[^ts-fc3-1]: `npm view <pkg> time --json` and `gh api` on 2026-10-29: detox 20.51.4 published 2026-06-16 (dist-tag latest), chromatic 18.13.5 on 2026-10-29T16:36Z, react-native-owl 1.5.0 on 2025-01-14, owl repo last commit 2025-01-15. Proof: tmp/refresh/testing/scratch/FC-3/npm.txt.
[^ts-fc3-2]: https://github.com/wix/Detox/issues/4963 comment by isilher, 2026-09-03 (RN 0.86.2 did not reproduce the `mMountItemDispatcher` crash), and issue 4973 body (Detox 20.51.4, RN 0.86.2, state OPEN on 2026-10-29).
[^ts-fc3-3]: https://github.com/appium/appium-uiautomator2-driver README, locator table: "Package identifier prefix is added automatically if unset" for the `id` strategy.
[^ts-asa-1]: https://www.ycombinator.com/companies/autosana (fetched 2026-10-29): Summer 2025, founded 2025, team size 5, founders Yuvan Sundrani and Jason Steinberg. The launch post says "Fully vision based". Vendor text.
[^ts-asa-2]: https://docs.autosana.ai/code-managed-files.md (fetched 2026-10-29): `.autosana/`, `*.flow.yaml`, required keys `name` and `instructions`. https://docs.autosana.ai/code-managed-migrate.md: `autosana flows export`. No Maestro or code export found.
[^ts-asa-3]: https://docs.autosana.ai/introduction (fetched 2026-10-29): "No Selectors", "Self-Healing". https://docs.autosana.ai/flows.md: run caching "5-8x speedup", best-effort, on by default. Vendor claims.
[^ts-asa-4]: https://docs.autosana.ai/app-build-guide.md (fetched 2026-10-29): `.app` zip simulator only, `.apk` for emulators and real devices, `.aab` not supported, React Native must be Release mode, Expo EAS profile with `simulator: true`.
[^ts-asa-5]: https://autosana.ai/pricing (fetched 2026-10-29): pay as you go $0.10 per AI action and $0.01 cached, 1,000 free actions per month, Startup $999 per month, Pro $2,499 per month with 5 physical device sessions, Enterprise custom.
[^ts-asa-6]: https://docs.autosana.ai/mcp-setup.md (fetched 2026-10-29): MCP URL, tools such as `flows_run`, `suites_run`, `pr_commit_flow_as_code`. https://docs.autosana.ai/install-cli.md: `autosana run`, `autosana flows validate`.
[^ts-asa-7]: https://docs.autosana.ai/introduction (fetched 2026-10-29) navigation: GitHub Bot, GitHub Action for App Uploads, GitLab CI, webhooks, Slack. Pages listed, not run by me.
[^ts-asa-8]: Scratch proof: tmp/refresh/testing/scratch/autosana/proof-pypi.txt (PyPI `autosana` 0.18.1, license Proprietary, 36 releases from 2026-03-25 to 2026-10-29) and proof-cli-help.txt (`autosana --help`). The npm package `autosana` (0.1.0) has a different maintainer. I did not link it to the vendor.
[^ts-asa-9]: https://autosana.ai/ footer and https://autosana.ai/security (fetched 2026-10-29): SOC 2 Type 1, Type 2 in review. The security page has a disclosure email only. Customer logos and quotes are vendor claims. No funding figure found.
[^ts-asa-10]: https://autosana.ai/product-updates (fetched 2026-10-29): latest entry 2026-09-21 "Multi-Device Testing".
[^ts-asa-11]: https://revyl.com/pricing/ (fetched 2026-10-29): Free, Starter $250 per month, Enterprise custom, overage $0.15 per minute for iOS simulators and $0.12 per minute for Android emulators, SOC 2 Type II badge. YC page https://www.ycombinator.com/companies/revyl seen in search only.
[^ts-asa-12]: https://www.mobileboost.io/ (fetched 2026-10-29): natural language tests, works inside XCUITest, Espresso, and Appium, "Backed by Y Combinator". The $799 figure is from https://www.testmuai.com/mobileboost-gpt-driver-alternative/, a competitor page (search snippet).
[^ts-asa-13]: https://www.qawolf.com/pricing (search snippet 2026-10-29): "$1 per web test run and $2 per mobile or desktop run". The page itself did not load for me. https://bug0.com/knowledge-base/qa-wolf-pricing (secondhand) says the model changed in 2026.
[^ts-asa-14]: https://www.mabl.com/pricing and https://www.mabl.com/ai-application-testing (search snippets 2026-10-29). The "about $450 a month" figure is from https://www.drizz.dev/post/mabl-testing, a competitor blog.
