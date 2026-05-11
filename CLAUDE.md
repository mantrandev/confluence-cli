# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A single zsh helper script (`Scripts/confluence.zsh`) that wraps the `acli` CLI for Confluence. Designed to be sourced in `.zshrc` for use by humans and AI agents.

## Dependencies

- `acli` — Atlassian CLI (must be installed and authenticated)
- `jq` — JSON processor

## Architecture

Everything lives in one file: `Scripts/confluence.zsh`.

**Private helpers** (prefixed `_confluence_`):
- `_confluence_require_acli` / `_confluence_require_jq` — guard checks
- `_confluence_has_flag` — checks if a flag is already in an args array
- `_confluence_space_id` — resolves a space key or name to a numeric ID via `acli`

**Public commands**:
- Auth: `cstatus`, `clogin`, `clogout`, `cswitch`
- Spaces: `cspaces`, `cspace`
- Pages: `cpage`, `ccontext`, `cpagebody`
- Blogs: `cblogs`, `cblog`, `cblogbody`
- Pass-through: `confluence`
- Help: `chelp`

**Key pattern**: Commands that accept a space accept either a numeric ID or a key/name — `_confluence_space_id` resolves it. Commands that accept body-format flags inject a default from `$CONFLUENCE_PAGE_BODY_FORMAT` / `$CONFLUENCE_BLOG_BODY_FORMAT` unless the caller already passed `--body-format`.

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `CONFLUENCE_SITE` | `""` | Atlassian site hostname |
| `CONFLUENCE_EMAIL` | `""` | Account email |
| `CONFLUENCE_PAGE_BODY_FORMAT` | `storage` | Default page body format |
| `CONFLUENCE_BLOG_BODY_FORMAT` | `storage` | Default blog body format |

## Testing

No automated tests. Manual validation: source the script and invoke commands against a real Confluence site.

```zsh
source Scripts/confluence.zsh
chelp
cstatus
```
