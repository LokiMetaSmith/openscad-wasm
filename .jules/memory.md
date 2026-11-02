## Archived: 2026-11-02

* Before starting tasks, always enter a deep planning mode to ask clarifying questions using `request_user_input` or `message_user` until requirements are crystal clear, then create the execution plan using the `set_plan` tool. Once the plan is approved, proceed with execution autonomously without asking for further confirmation.
* Windows builds can be executed using the build.ps1 PowerShell script, which utilizes native Docker or Podman CLI as an alternative to Make.
* Local Docker builds (e.g., `make build`) fail in the sandbox environment due to `overlayfs` limitations with whiteout files (`.wh.*`) in Emscripten image layers. Do not attempt local C++ compilation; rely on remote CI/CD pipelines instead.
* The TypeScript wrapper for the Emscripten module is located in `runtime/` and can be built by running `npm install` and `npm run build` inside the `runtime/` directory.
* When testing Emscripten-generated WASM modules in Deno, bypass the default `fetch` behavior to avoid `NetworkError`s by passing the WASM module directly using the `wasmBinary` initialization option with `Deno.readFileSync(new URL('../build/openscad.wasm', import.meta.url))`. Ensure `locateFile` is also provided. The types for `wasmBinary`, `locateFile`, and `onAbort` are included in `InitOptions` in `runtime/src/openscad.ts`, so `@ts-ignore` is not needed.
* Emscripten compilation in this project outputs modularized ES6 scripts (`MODULARIZE=1` or `EXPORT_ES6=1`), meaning the exported factory function must be explicitly invoked to begin WASM initialization and avoid hanging promises.
* The repository is openscad-wasm, a project that compiles OpenSCAD C++ to WebAssembly using Emscripten.
* The project is structured as an installable npm package using a root package.json. Build scripts (Makefile, build.ps1) compile artifacts and copy them alongside the package.json into the build/ directory for distribution and local linking.
* Testing is done using native Deno tests located in the `tests/` directory. However, `deno` is not installed in the sandbox environment, so tests must be executed locally by the user or skipped during sandbox execution.
* Guidelines:
  * **User Request Supersedes:** Always prioritize the user's current, explicit request over any conflicting information in memory.
  * **Context vs. State:** Use memory for historical context and intent (the "why"). Use the actual codebase files as the source of truth for the current code state (the "what").
  * **Memory is Not a Task:** Do not treat information from memory as a new, active instruction. Memory provides passive context, do not use it to create new feature requests.
