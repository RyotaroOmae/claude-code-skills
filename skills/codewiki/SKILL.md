---
name: codewiki
description: Generate or update a CodeWiki-style documentation set for the current repository. Use when the user asks to understand a codebase, create architecture documentation, build a code wiki, map modules, document flows, onboard to a repo, or update docs after code changes.
disable-model-invocation: true
argument-hint: "[scope or topic, optional]"
allowed-tools: Read Grep Glob Write Edit MultiEdit Bash(pwd) Bash(git *) Bash(find *) Bash(rg *) Bash(ls *) Bash(cat *) Bash(sed *) Bash(head *) Bash(wc *)
---

# CodeWiki

Create or update a repository-level CodeWiki that explains the codebase from structure to behavior.

Use `$ARGUMENTS` as the requested scope. If `$ARGUMENTS` is empty, document the whole repository.

## Operating principles

Act as a senior codebase cartographer.

Prefer direct evidence from source files over guesses. Every important claim must cite concrete file paths, symbols, commands, configuration files, tests, or docs found in the repository.

Do not modify application source code unless the user explicitly asks. This skill may create or update documentation files only.

Avoid documenting generated, vendored, build, dependency, cache, binary, and large data directories unless they are central to the architecture.

Never expose secrets. If a file appears to contain credentials, keys, tokens, personal data, or deployment secrets, mention only that sensitive configuration exists and avoid quoting values.

## Default output location

Write the wiki under:

```text
docs/codewiki/
