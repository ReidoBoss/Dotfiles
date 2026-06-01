# Claude Instructions For This Bash Directory

You are working in a dependency-free Bash directory. The company policy is strict: do not add third-party dependencies of any kind.

## Hard Requirements

- Write Bash functions meant to be sourced, not standalone `.sh` scripts.
- Use files ending in `.bash` unless the user requests another name.
- Do not add package managers, plugins, vendored tools, generated dependency files, or install instructions.
- Prefer Bash builtins and parameter expansion. Use common Linux utilities only when they are clearly the best practical option.
- Keep code generic across normal Linux environments.

## Allowed Baseline Tools

Common built-in Linux utilities are acceptable when needed: `awk`, `sed`, `grep`, `find`, `sort`, `wc`, `head`, `cut`, `tr`, `mktemp`, `tput`, `cat`, `printf`, and `rm`.

Avoid optional tools such as `fzf`, `jq`, `perl`, `python`, `node`, `ruby`, `bats`, and any package-specific CLI.

## Style

- Use 2-space indentation.
- Public functions should look like:

  ```bash
  function-name() {
    ...
  }
  ```

- Use `local` variables inside functions.
- Quote expansions by default.
- Prefer `printf` to `echo`.
- Keep code readable first, portable second, and optimized where it matters.
- Preserve caller shell state when changing `IFS`, traps, terminal settings, or shell options.

## Strict Mode

Use strict-mode discipline by default: validate arguments, handle unset values explicitly, and return non-zero on failure.

Use `set -euo pipefail` for standalone execution contexts only. In sourced function files, avoid setting strict mode globally because it changes the user's shell. If strict options are enabled inside a function, save and restore the previous state.

## Help And Validation

Every public function must support `-h` and `--help`.

Help output should include:

- one-line description
- usage
- examples
- controls or notes when relevant

Validate input before doing work. Document intentional shell side effects.

## Verification

Do not add a test framework. Keep code ShellCheck-friendly, but ShellCheck is not a dependency.

Use lightweight checks such as:

```bash
bash -n file.bash
```

For interactive functions, also document the manual command used to verify behavior.
