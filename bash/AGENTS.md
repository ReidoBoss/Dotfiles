# Bash Project Instructions

This directory contains Bash functions intended to be sourced into an interactive shell. Do not create standalone `.sh` entrypoint scripts unless the user explicitly asks for one.

## Project Constraints

- Use Bash only. Prefer Bash builtins and shell parameter expansion before external commands.
- Do not add third-party dependencies, package managers, plugins, vendored tools, or install steps.
- Standard Linux userland commands may be used when they are the right tool, but keep them conservative and common: `awk`, `sed`, `grep`, `find`, `sort`, `wc`, `head`, `cut`, `tr`, `mktemp`, `tput`, `cat`, `printf`, `rm`, and similar baseline utilities.
- Keep functions generic across Linux environments. Avoid GNU-only flags unless the surrounding code already relies on them or there is no reasonable portable option.
- Do not assume optional tools such as `fzf`, `jq`, `perl`, `python`, `node`, `ruby`, `shellcheck`, `bats`, or package-specific CLIs.

## Code Shape

- Add or edit `.bash` files containing sourced functions, for example:

  ```bash
  example-function() {
    ...
  }
  ```

- Use 2-space indentation.
- Prefer readable, maintainable Bash over cleverness. Optimize process spawning only when it materially improves an interactive function or hot path.
- Use `local` for function variables.
- Quote variable expansions unless word splitting or glob expansion is intentionally required.
- Prefer `printf` over `echo` for predictable output.
- Preserve and restore shell state when changing globals such as `IFS`, terminal visibility, traps, or shell options.
- Use temporary directories from `mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"` when multiple temporary files are needed, and clean them up.

## Strict Mode

- Use strict-mode thinking by default: fail clearly, validate inputs, and handle unset variables deliberately.
- For standalone execution contexts, use:

  ```bash
  set -euo pipefail
  ```

- For sourced function files, be careful before setting global shell options because they affect the caller's interactive shell. Prefer strict handling inside functions with explicit checks, guarded expansions such as `${var:-}`, and clear return paths.
- If a function enables strict options, save the previous shell option state and restore it before returning.

## Function Behavior

- Every public function should support `-h` and `--help`.
- Help text should include a short description, usage, examples, and relevant notes or controls.
- Validate arguments before doing work. Return non-zero on invalid usage or operational failure.
- Avoid surprising side effects in the caller's shell. If side effects are intentional, document them in help text.
- Prefer `VISUAL`, then `EDITOR`, then a conservative fallback when opening an editor.

## Lint And Testing

- Keep code ShellCheck-friendly, but do not make ShellCheck a project dependency.
- Avoid adding a test framework. For verification, use lightweight built-in checks such as:

  ```bash
  bash -n file.bash
  ```

- When behavior needs manual verification, document the exact function command that was tested.

## Collaboration Rules

- Ask questions when requirements affect portability, shell state, user interaction, or dependency policy.
- Do not install anything to complete a task.
- Do not replace Bash with another language.
- Keep edits scoped to this directory and to the requested behavior.
