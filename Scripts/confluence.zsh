# Atlassian CLI helpers — Confluence read helpers for agents
# Source this file in .zshrc after optionally setting:
#
#   export CONFLUENCE_SITE="your-team.atlassian.net"
#   export CONFLUENCE_EMAIL="user@company.com"
#   source /path/to/confluence.zsh
#
# Read-focused commands default to JSON output for AI agents.

: "${CONFLUENCE_SITE:=}"
: "${CONFLUENCE_EMAIL:=}"
: "${CONFLUENCE_PAGE_BODY_FORMAT:=storage}"
: "${CONFLUENCE_BLOG_BODY_FORMAT:=storage}"
export CONFLUENCE_SITE CONFLUENCE_EMAIL

_confluence_require_acli() {
  (( $+commands[acli] )) && return 0
  echo "Missing command: acli" >&2
  return 1
}

_confluence_require_jq() {
  (( $+commands[jq] )) && return 0
  echo "Missing command: jq" >&2
  return 1
}

_confluence_has_flag() {
  local wanted="$1"
  shift

  local arg
  for arg in "$@"; do
    [[ "$arg" == "$wanted" || "$arg" == ${wanted}=* ]] && return 0
  done

  return 1
}

_confluence_space_id() {
  local input="$1"
  local raw_json id

  if [[ -z "$input" ]]; then
    echo "Missing space input" >&2
    return 1
  fi

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
    return 0
  fi

  _confluence_require_acli || return 1
  _confluence_require_jq || return 1

  raw_json="$(acli confluence space list --keys "$input" --limit 1 --json 2>/dev/null)" || {
    echo "Failed to resolve Confluence space: $input" >&2
    return 1
  }

  id="$(
    print -r -- "$raw_json" | jq -r '
      def items:
        if type == "array" then .
        elif .results? then .results
        elif .data?.results? then .data.results
        elif .items? then .items
        elif .data?.items? then .data.items
        elif .values? then .values
        elif .data?.values? then .data.values
        elif .id? then [.]
        else []
        end;

      items
      | map(select((.key // "") == $key or (.name // "") == $key))
      | .[0].id // empty
    ' --arg key "$input"
  )"

  if [[ -z "$id" ]]; then
    echo "Could not resolve Confluence space: $input" >&2
    return 1
  fi

  echo "$id"
}

confluence() {
  _confluence_require_acli || return 1
  acli confluence "$@"
}

cstatus() {
  _confluence_require_acli || return 1
  acli confluence auth status
}

clogin() {
  _confluence_require_acli || return 1

  local site="${1:-$CONFLUENCE_SITE}"
  if [[ -n "$site" ]]; then
    acli confluence auth login --web --site "$site"
  else
    acli confluence auth login --web
  fi
}

clogout() {
  _confluence_require_acli || return 1
  acli confluence auth logout
}

cswitch() {
  _confluence_require_acli || return 1

  local site="${1:-$CONFLUENCE_SITE}"
  local email="${2:-$CONFLUENCE_EMAIL}"

  if [[ -n "$site" && -n "$email" ]]; then
    acli confluence auth switch --site "$site" --email "$email"
  elif [[ -n "$site" ]]; then
    acli confluence auth switch --site "$site"
  elif [[ -n "$email" ]]; then
    acli confluence auth switch --email "$email"
  else
    acli confluence auth switch
  fi
}

cspaces() {
  _confluence_require_acli || return 1
  acli confluence space list --json "$@"
}

cspace() {
  _confluence_require_acli || return 1

  local input="$1"

  if [[ -z "$input" ]]; then
    echo 'Usage: cspace <space-id|space-key> [acli space view flags...]' >&2
    return 1
  fi

  shift

  local space_id
  space_id="$(_confluence_space_id "$input")" || return 1

  acli confluence space view --id "$space_id" --json "$@"
}

cpage() {
  _confluence_require_acli || return 1

  local page_id="$1"

  if [[ -z "$page_id" ]]; then
    echo 'Usage: cpage <page-id> [acli page view flags...]' >&2
    return 1
  fi

  shift

  local -a extra_args
  extra_args=("$@")

  if ! _confluence_has_flag "--body-format" "${extra_args[@]}"; then
    extra_args=(--body-format "$CONFLUENCE_PAGE_BODY_FORMAT" "${extra_args[@]}")
  fi

  acli confluence page view --id "$page_id" --json "${extra_args[@]}"
}

ccontext() {
  _confluence_require_acli || return 1

  local page_id="$1"

  if [[ -z "$page_id" ]]; then
    echo 'Usage: ccontext <page-id> [extra page view flags...]' >&2
    return 1
  fi

  shift

  local -a extra_args
  extra_args=("$@")

  if ! _confluence_has_flag "--body-format" "${extra_args[@]}"; then
    extra_args=(--body-format "$CONFLUENCE_PAGE_BODY_FORMAT" "${extra_args[@]}")
  fi

  acli confluence page view \
    --id "$page_id" \
    --json \
    --include-direct-children \
    --include-labels \
    --include-properties \
    --include-version \
    "${extra_args[@]}"
}

cpagebody() {
  _confluence_require_jq || return 1

  local page_id="$1"

  if [[ -z "$page_id" ]]; then
    echo 'Usage: cpagebody <page-id> [page view flags...]' >&2
    return 1
  fi

  shift

  cpage "$page_id" "$@" | jq -r '
    [
      .body.storage.value?,
      .body.view.value?,
      .body.atlas_doc_format.value?,
      .body.value?,
      .value?
    ]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  '
}

cblogs() {
  _confluence_require_acli || return 1

  local input="$1"

  if [[ -z "$input" ]]; then
    echo 'Usage: cblogs <space-id|space-key> [acli blog list flags...]' >&2
    return 1
  fi

  shift

  local space_id
  space_id="$(_confluence_space_id "$input")" || return 1

  acli confluence blog list --space-id "$space_id" --json "$@"
}

cblog() {
  _confluence_require_acli || return 1

  local blog_id="$1"

  if [[ -z "$blog_id" ]]; then
    echo 'Usage: cblog <blog-id> [acli blog view flags...]' >&2
    return 1
  fi

  shift

  local -a extra_args
  extra_args=("$@")

  if ! _confluence_has_flag "--body-format" "${extra_args[@]}"; then
    extra_args=(--body-format "$CONFLUENCE_BLOG_BODY_FORMAT" "${extra_args[@]}")
  fi

  acli confluence blog view --id "$blog_id" --json "${extra_args[@]}"
}

cblogbody() {
  _confluence_require_jq || return 1

  local blog_id="$1"

  if [[ -z "$blog_id" ]]; then
    echo 'Usage: cblogbody <blog-id> [blog view flags...]' >&2
    return 1
  fi

  shift

  cblog "$blog_id" "$@" | jq -r '
    [
      .body.storage.value?,
      .body.view.value?,
      .body.atlas_doc_format.value?,
      .body.value?,
      .value?
    ]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  '
}

_confluence_xml_to_md() {
  local tmpxml
  tmpxml="$(mktemp /tmp/cfxml.XXXXXX)"
  cat > "$tmpxml"
  python3 - "$tmpxml" <<'PYEOF'
import sys, re

def convert(xml):
    code_blocks = []
    def save_code(m):
        code_blocks.append(m.group(1))
        return f'__CODE_{len(code_blocks)-1}__'

    xml = re.sub(r'<ac:plain-text-body[^>]*><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>', save_code, xml, flags=re.DOTALL)

    # drop visual-only macros entirely (diagrams, ToC, etc.)
    for macro in ('drawio', 'toc', 'macro-pack', 'recently-updated', 'widget'):
        xml = re.sub(rf'<ac:structured-macro[^>]*ac:name="{macro}"[^>]*>.*?</ac:structured-macro>', '', xml, flags=re.DOTALL)

    # drop ac:parameter tags and their content (macro config noise)
    xml = re.sub(r'<ac:parameter[^>]*>.*?</ac:parameter>', '', xml, flags=re.DOTALL)

    # keep ac:rich-text-body content, drop the wrapper tags
    xml = re.sub(r'<ac:rich-text-body[^>]*>', '', xml)
    xml = re.sub(r'</ac:rich-text-body>', '', xml)

    # drop remaining ac:/ri: tags
    xml = re.sub(r'</?ac:[^>]+>', '', xml)
    xml = re.sub(r'<ri:[^>]+/?>', '', xml)

    for i in range(1, 7):
        xml = re.sub(rf'<h{i}[^>]*>(.*?)</h{i}>', lambda m, n=i: '\n' + '#'*n + ' ' + re.sub('<[^>]+>', '', m.group(1)).strip() + '\n', xml, flags=re.DOTALL)

    xml = re.sub(r'<strong[^>]*>(.*?)</strong>', r'**\1**', xml, flags=re.DOTALL)
    xml = re.sub(r'<em[^>]*>(.*?)</em>', r'_\1_', xml, flags=re.DOTALL)
    xml = re.sub(r'<code[^>]*>(.*?)</code>', r'`\1`', xml, flags=re.DOTALL)
    xml = re.sub(r'<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', r'[\2](\1)', xml, flags=re.DOTALL)

    def fmt_table(m):
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', m.group(0), re.DOTALL)
        out = []
        for i, row in enumerate(rows):
            cells = re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', row, re.DOTALL)
            line = '| ' + ' | '.join(re.sub('<[^>]+>', '', c).strip() for c in cells) + ' |'
            out.append(line)
            if i == 0:
                out.append('| ' + ' | '.join('---' for _ in cells) + ' |')
        return '\n' + '\n'.join(out) + '\n'
    xml = re.sub(r'<table[^>]*>.*?</table>', fmt_table, xml, flags=re.DOTALL)

    def fmt_list(m, ordered=False):
        items = re.findall(r'<li[^>]*>(.*?)</li>', m.group(0), re.DOTALL)
        lines = []
        for idx, item in enumerate(items):
            text = re.sub('<[^>]+>', '', item).strip()
            prefix = f'{idx+1}.' if ordered else '-'
            lines.append(f'{prefix} {text}')
        return '\n' + '\n'.join(lines) + '\n'
    xml = re.sub(r'<ol[^>]*>(.*?)</ol>', lambda m: fmt_list(m, ordered=True), xml, flags=re.DOTALL)
    xml = re.sub(r'<ul[^>]*>(.*?)</ul>', fmt_list, xml, flags=re.DOTALL)

    xml = re.sub(r'<p[^>]*>(.*?)</p>', lambda m: '\n' + re.sub('<[^>]+>', '', m.group(1)).strip() + '\n', xml, flags=re.DOTALL)
    xml = re.sub(r'<[^>]+>', '', xml)

    for i, code in enumerate(code_blocks):
        xml = xml.replace(f'__CODE_{i}__', '\n```\n' + code.strip() + '\n```\n')

    xml = xml.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&nbsp;', ' ')
    xml = xml.replace('&#39;', "'").replace('&quot;', '"').replace('&zwj;', '').replace('&bull;', '•')
    xml = re.sub(r'&[a-zA-Z]+;', '', xml)  # strip any remaining named entities
    xml = re.sub(r'\n{3,}', '\n\n', xml)
    return xml.strip()

data = open(sys.argv[1]).read()
print(convert(data))
PYEOF
  rm -f "$tmpxml"
}

cread() {
  _confluence_require_acli || return 1
  _confluence_require_jq || return 1

  local page_id="$1"
  if [[ -z "$page_id" ]]; then
    echo 'Usage: cread <page-id>' >&2
    return 1
  fi

  local title body
  local json
  json="$(acli confluence page view --id "$page_id" --body-format storage --json 2>/dev/null)"
  title="$(print -r -- "$json" | jq -r '.title // empty')"
  body="$(print -r -- "$json" | jq -r '
    [.body.storage.value?, .body.view.value?, .body.value?, .value?]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  ')"

  if [[ -n "$title" ]]; then
    printf '# %s\n\n' "$title"
  fi

  print -r -- "$body" | _confluence_xml_to_md
}

cblogread() {
  _confluence_require_acli || return 1
  _confluence_require_jq || return 1

  local blog_id="$1"
  if [[ -z "$blog_id" ]]; then
    echo 'Usage: cblogread <blog-id>' >&2
    return 1
  fi

  local json title body
  json="$(acli confluence blog view --id "$blog_id" --body-format storage --json 2>/dev/null)"
  title="$(print -r -- "$json" | jq -r '.title // empty')"
  body="$(print -r -- "$json" | jq -r '
    [.body.storage.value?, .body.view.value?, .body.value?, .value?]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  ')"

  if [[ -n "$title" ]]; then
    printf '# %s\n\n' "$title"
  fi

  print -r -- "$body" | _confluence_xml_to_md
}

_chelp_heading()  { printf '\n%s\n' "$1"; }
_chelp_meta()     { printf '  %-8s %s\n' "$1" "$2"; }
_chelp_cmd()      { printf '  %-52s %s\n' "$1" "$2"; }
_chelp_cmd_wrap() { printf '  %s\n' "$1"; printf '  %-52s %s\n' "" "$2"; }

chelp() {
  printf 'Confluence helpers\n'
  _chelp_meta "Site:" "${CONFLUENCE_SITE:-<unset>}"
  _chelp_meta "Email:" "${CONFLUENCE_EMAIL:-<unset>}"
  _chelp_meta "Output:" "JSON by default for AI-agent reads"

  _chelp_heading "Auth"
  _chelp_cmd "cstatus" "Show Confluence auth status"
  _chelp_cmd "clogin [site]" "Login in browser; falls back to CONFLUENCE_SITE"
  _chelp_cmd "clogout" "Logout current Confluence session"
  _chelp_cmd "cswitch [site] [email]" "Switch Confluence account"

  _chelp_heading "Spaces"
  _chelp_cmd "cspaces [acli space list flags...]" "List accessible spaces as JSON"
  _chelp_cmd "cspace [SPACE_ID|SPACE_KEY] [view flags...]" "View one space as JSON"

  _chelp_heading "Pages"
  _chelp_cmd "cpage [PAGE_ID] [page view flags...]" "View one page as JSON"
  _chelp_cmd_wrap "ccontext [PAGE_ID] [page view flags...]" "View one page with children, labels, properties, and version"
  _chelp_cmd "cpagebody [PAGE_ID] [page view flags...]" "Print only the resolved page body"
  _chelp_cmd "cread [PAGE_ID]" "Print page as readable markdown in terminal"

  _chelp_heading "Blogs"
  _chelp_cmd "cblogs [SPACE_ID|SPACE_KEY] [blog list flags...]" "List blog posts in a space as JSON"
  _chelp_cmd "cblog [BLOG_ID] [blog view flags...]" "View one blog post as JSON"
  _chelp_cmd "cblogbody [BLOG_ID] [blog view flags...]" "Print only the resolved blog body"
  _chelp_cmd "cblogread [BLOG_ID]" "Print blog post as readable markdown in terminal"

  _chelp_heading "Raw pass-through"
  _chelp_cmd "confluence <acli confluence args...>" "Pass through to acli confluence"
  _chelp_cmd "chelp" "Show this help"
}
