> [!NOTE] 
> Last update: RN v0.88.1 (main `9c7b0f5fafd`) 2026-10-29

# The React Native New Architecture Book

> A deep-dive book on the React Native New Architecture, covering core concepts, practical guides, real-world case studies, and more.

This page is the table of contents for an 18-chapter book on the React Native New Architecture. Each chapter is grounded in the official React Native repository, the official documentation, and real-world libraries.

**Status:** verified against React Native `main` at commit
[`9c7b0f5fafd`](https://github.com/facebook/react-native/commit/9c7b0f5fafdaa986bd3dcff7d65c3d8d59861176)
(v0.88.1 era, refresh 2026-10-29; previous refresh was v0.87.0-rc.3).
Delta since `ca750feefb1` covers `v0.87.0`, `v0.87.1`, the 0.88 RC train,
`v0.88.0`, `v0.88.1`, and 795 commits on `main` after `v0.88.1`.
See [`CHANGELOG.md`](./CHANGELOG.md) for the full delta and each
chapter's YAML frontmatter `taillog` for per-chapter history.

This documentation has been thoroughly updated to reflect the current
state of the New Architecture, which is now enabled by default, **cannot
be opted out of** on RN ≥ 0.82, and continues to hard-wire TurboModules
and delete legacy Bridge / interop surfaces on the v0.87 and v0.88 lines.[^1]

Tip: Many chapters now include Mermaid diagrams (rendered on GitHub) to
visualize the Bridge vs JSI call paths, Fabric's render pipeline,
TurboModule CodeGen, Bridgeless interop, and the migration flow.

---

## 📚 Table of Contents

### Part 1: Core Architecture

*   [Chapter 1: Introduction - The "Why"](./01-Introduction-The-Why.md)
    *   A deep dive into the limitations of the original architecture and the vision for the new one.
*   [Chapter 2: JSI - The Foundation](./02-JSI-The-Foundation.md)
    *   An exploration of the JavaScript Interface (JSI) and its role as the cornerstone of the new architecture.
*   [Chapter 3: Fabric - The New Renderer](./03-Fabric-The-New-Renderer.md)
    *   A detailed look at the new rendering system that replaces UIManager.
*   [Chapter 4: TurboModules - The New Native Modules](./04-Turbo-Modules-The-New-Native-Modules.md)
    *   Understanding the next generation of native modules and their benefits.
*   [Chapter 5: CodeGen - The Automation Engine](./05-CodeGen-The-Automation-Engine.md)
    *   An analysis of the tooling that automates the generation of "glue code."
*   [Chapter 6: Bridgeless - The Ultimate Goal](./06-Bridgeless-The-Ultimate-Goal.md)
    *   Investigating the progress and implications of running React Native without the original Bridge.

### Part 2: Practical Application & Guides

*   [Chapter 7: Migration and Adoption](./07-Migration-And-Adoption.md)
    *   A practical guide for developers on migrating their apps and libraries.
*   [Chapter 8: Performance Analysis](./08-Performance-Analysis.md)
    *   A review of benchmarks and performance improvements.
*   [Chapter 9: Conclusion and Future](./09-Conclusion-And-Future.md)
    *   A summary of the key advancements and a look at the future roadmap.
*   [Chapter 10: Common Mistakes and Misunderstandings](./10-Common-Mistakes.md)
    *   A guide to frequent errors and pitfalls when working with the New Architecture.
*   [Chapter 11: Best Practices](./11-Best-Practices.md)
    *   A list of do's and don'ts for writing performant and maintainable code.
*   [Chapter 12: Frequently Asked Questions (FAQs)](./12-FAQs.md)
    *   A list of common high-level questions and their answers.

### Part 3: Real-World Examples & Tooling

*   [Chapter 13: Case Study - `react-native-vision-camera`](./13-Case-Study-Vision-Camera.md)
    *   An analysis of how a production library blends legacy view managers with JSI frame processors while preparing for the New Architecture.
*   [Chapter 14: Alternative Tooling - Nitro](./14-Alternative-Tooling-Nitro.md)
    *   An exploration of a high-level framework that provides an alternative developer experience for creating native modules.
*   [Chapter 15: Tutorial - Building a Native Module and Component](./15-Tutorial-Building-From-Scratch.md)
    *   A hands-on tutorial building a simple Fabric component and TurboModule from scratch.
*   [Chapter 16: Additional Resources and Checklists](./16-Additional-Resources-and-Checklists.md)
    *   A collection of useful checklists and resources for migration and development.
*   [Chapter 17: Top 27 React Native Interview Questions](./17-Interview-Questions.md)
    *   Short spoken answers, key points, common wrong answers, and follow-ups. Each fact has a source footnote.
*   [Chapter 18: Testing React Native Apps](./18-Testing-React-Native-Apps.md)
    *   Jest and Testing Library, Detox, Maestro and Appium, test history, device clouds and CI, and agentic AI with MCP servers.

---

## Version and audit

This book is versioned against the React Native version it is
**verified against**, not against an internal version. The current
verified-against version is `v0.88.1+main` (RN `main` HEAD
`9c7b0f5fafd` as of 2026-10-29). See [`CHANGELOG.md`](./CHANGELOG.md)
for the per-version delta.


### Contributing

Pull requests are welcome. If you find a factual error against a
specific RN release, please cite an `<rn-source-path>:<line>` reference
or a CHANGELOG entry. The book aims to be source-grounded; PR
descriptions should follow that bar.

---

## Footnotes

[^1]: The New Architecture is hard-wired on in the current React Native source. On iOS, `NewArchitectureHelper.new_arch_enabled` in `packages/react-native/scripts/cocoapods/new_architecture.rb` returns `true` unconditionally. On Android, `ProjectUtils.isNewArchEnabled()` always returns `true`, and the Gradle plugin at `packages/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/ReactRootProjectPlugin.kt` rejects `newArchEnabled=false` (unsupported since React Native 0.82). TurboModules are likewise always on: the `useTurboModules` feature flag was removed in v0.87.0-rc.0. `RCTTurboModuleEnabled()` still exists in v0.88.1 and returns `YES` (`RCTBridge.mm`). Commit `01d55273bcf` deletes it on `main`. The default was originally flipped for new apps in v0.76.0 (2024-10-23).
