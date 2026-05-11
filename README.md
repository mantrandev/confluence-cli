# confluence-cli

Zsh helper functions for Confluence, wrapping the [`acli`](https://acli.atlassian.com) CLI. Designed for both human and AI-agent use — all read commands return JSON by default.

## Requirements

- [`acli`](https://acli.atlassian.com) — Atlassian CLI
- [`jq`](https://jqlang.github.io/jq/)

## Setup

```zsh
# Optional: set defaults
export CONFLUENCE_SITE="your-team.atlassian.net"
export CONFLUENCE_EMAIL="user@company.com"

source /path/to/Scripts/confluence.zsh
```

Then authenticate:

```zsh
clogin          # opens browser login
cstatus         # verify auth
```

## Commands

```
Auth
  cstatus                                   Show auth status
  clogin [site]                             Login via browser
  clogout                                   Logout current session
  cswitch [site] [email]                    Switch account

Spaces
  cspaces [flags...]                        List accessible spaces
  cspace <SPACE_ID|KEY> [flags...]          View one space

Pages
  cpage <PAGE_ID> [flags...]                View one page as JSON
  ccontext <PAGE_ID> [flags...]             Page with children, labels, props, version
  cpagebody <PAGE_ID> [flags...]            Print only the page body

Blogs
  cblogs <SPACE_ID|KEY> [flags...]          List blog posts in a space
  cblog <BLOG_ID> [flags...]                View one blog post as JSON
  cblogbody <BLOG_ID> [flags...]            Print only the blog body

Pass-through
  confluence <args...>                      Raw acli confluence pass-through
  chelp                                     Show help
```

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `CONFLUENCE_SITE` | — | Atlassian site hostname |
| `CONFLUENCE_EMAIL` | — | Account email |
| `CONFLUENCE_PAGE_BODY_FORMAT` | `storage` | Default page body format |
| `CONFLUENCE_BLOG_BODY_FORMAT` | `storage` | Default blog body format |
