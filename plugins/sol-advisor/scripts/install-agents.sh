#!/bin/sh
# Install Sol Advisor's shipped custom-agent templates without changing Codex config.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir PATH] [--check]

Install Sol Advisor's four current custom-agent templates into the target directory.
Normal mode also replaces the recognized predecessor Sol template and removes the
exact v0.7.0 legacy Terra template. It never overwrites a modified, nonregular,
or symlinked destination.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --check            Verify that Implementer, reviewer, consultant, and the floor lane match exactly and no
                     legacy Terra file remains; do not create, replace, or remove anything.
  --help             Show this help text.
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

report_preflight_error() {
  printf '%s\n' "ERROR: $*" >&2
  preflight_failed=1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
}

classify_current_or_legacy() {
  destination=$1
  template=$2
  legacy_digest=$3

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    digest=$(sha256_file "$destination")
    if [ -n "$legacy_digest" ] && [ "$digest" = "$legacy_digest" ]; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

classify_legacy_luna() {
  destination=$1

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    if [ "$digest" = "$legacy_luna_sha256" ]; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

classify_legacy_terra() {
  destination=$1

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    if [ "$digest" = "$legacy_terra_sha256" ]; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

same_state() {
  label=$1
  expected=$2
  actual=$3
  [ "$expected" = "$actual" ] || fail "$label changed after preflight; no further destination files were changed."
}

install_missing() {
  template=$1
  destination=$2
  staged=''

  if path_exists "$destination"; then
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  staged=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage template for installation: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $destination"
  fi

  if ! ln "$staged" "$destination"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

replace_legacy_terra() {
  [ "$(classify_legacy_terra "$terra_destination")" = legacy ] ||
    fail "legacy Terra destination changed after preflight and will not be removed: $terra_destination"
  rm "$terra_destination" || fail "could not remove exact legacy Terra template: $terra_destination"
  printf '%s\n' "REMOVED LEGACY: $terra_destination"
}

replace_legacy_sol() {
  staged=''

  [ "$(classify_current_or_legacy "$sol_destination" "$sol_template" "$prev_sol_sha256")" = legacy ] ||
    fail "legacy Sol destination changed after preflight and will not be replaced: $sol_destination"

  staged=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage migrated Sol template: $sol_destination"
  if ! cp "$sol_template" "$staged"; then
    rm -f "$staged"
    fail "could not stage migrated Sol template: $sol_destination"
  fi

  [ "$(classify_current_or_legacy "$sol_destination" "$sol_template" "$prev_sol_sha256")" = legacy ] || {
    rm -f "$staged"
    fail "legacy Sol destination changed after preflight and will not be replaced: $sol_destination"
  }

  if ! mv -f "$staged" "$sol_destination"; then
    rm -f "$staged"
    fail "could not replace exact legacy Sol template: $sol_destination"
  fi

  printf '%s\n' "MIGRATED: $sol_destination"
}

remove_legacy_luna() {
  [ "$(classify_legacy_luna "$luna_destination")" = legacy ] ||
    fail "legacy Luna destination changed after preflight and will not be removed: $luna_destination"
  rm "$luna_destination" || fail "could not remove exact legacy Luna template: $luna_destination"
  printf '%s\n' "REMOVED LEGACY: $luna_destination"
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

check_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a path."
      [ -n "$2" ] || fail "--target-dir requires a non-empty path."
      case "$2" in
        --*) fail "--target-dir path must be explicit; prefix an option-like relative name with ./ or use an absolute path." ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

case "$target_dir" in
  /*) ;;
  *) target_dir=$(pwd -P)/$target_dir ;;
esac

case "$target_dir" in
  /|//) fail "refusing to use the filesystem root as an agent target directory." ;;
esac

implementer_file=sol-advisor-luna-implementer.toml
sol_file=sol-advisor-sol-reviewer.toml
consultant_file=sol-advisor-sol-consultant.toml
floor_file=sol-advisor-luna-committer.toml
terra_file=sol-advisor-terra-implementer.toml
implementer_template=$template_dir/$implementer_file
sol_template=$template_dir/$sol_file
consultant_template=$template_dir/$consultant_file
floor_template=$template_dir/$floor_file
implementer_destination=$target_dir/$implementer_file
sol_destination=$target_dir/$sol_file
consultant_destination=$target_dir/$consultant_file
floor_destination=$target_dir/$floor_file
terra_destination=$target_dir/$terra_file

# Immutable v0.2.0 byte digests
legacy_luna_sha256=fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb

# v0.7.0 Terra implementer digest (now legacy)
legacy_terra_sha256=06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d

# Digest of the previously shipped Sol reviewer template, so an installed copy of the
# prior release migrates instead of being refused as a conflict. Add the predecessor
# digest here whenever a shipped template changes.
prev_sol_sha256=0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2

for template in "$implementer_template" "$sol_template" "$consultant_template" "$floor_template"; do
  [ -f "$template" ] && [ ! -L "$template" ] ||
    fail "shipped template is missing or not a regular file: $template"
done

preflight_failed=0
if path_exists "$target_dir"; then
  if [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; then
    report_preflight_error "target directory is not a real directory: $target_dir"
  fi
fi

implementer_state=$(classify_current_or_legacy "$implementer_destination" "$implementer_template" '')
sol_state=$(classify_current_or_legacy "$sol_destination" "$sol_template" "$prev_sol_sha256")
consultant_state=$(classify_current_or_legacy "$consultant_destination" "$consultant_template" '')
floor_state=$(classify_current_or_legacy "$floor_destination" "$floor_template" '')
terra_state=$(classify_legacy_terra "$terra_destination")

if [ "$check_only" -eq 1 ]; then
  [ "$implementer_state" = current ] ||
    report_preflight_error "Implementer template is $implementer_state, not the current exact file: $implementer_destination"
  [ "$sol_state" = current ] ||
    report_preflight_error "Sol template is $sol_state, not the current exact file: $sol_destination"
  [ "$consultant_state" = current ] ||
    report_preflight_error "Sol consultant template is $consultant_state, not the current exact file: $consultant_destination"
  [ "$floor_state" = current ] ||
    report_preflight_error "floor-lane template is $floor_state, not the current exact file: $floor_destination"
  [ "$terra_state" = missing ] ||
    report_preflight_error "legacy Terra file remains or is unsafe: $terra_destination"
else
  case "$implementer_state" in
    current|missing) ;;
    *) report_preflight_error "Implementer destination is $implementer_state and will not be replaced: $implementer_destination" ;;
  esac
  case "$sol_state" in
    current|legacy|missing) ;;
    *) report_preflight_error "Sol destination is $sol_state and will not be replaced: $sol_destination" ;;
  esac
  case "$consultant_state" in
    current|missing) ;;
    *) report_preflight_error "Sol consultant destination is $consultant_state and will not be replaced: $consultant_destination" ;;
  esac
  case "$floor_state" in
    current|missing) ;;
    *) report_preflight_error "floor-lane destination is $floor_state and will not be replaced: $floor_destination" ;;
  esac
  case "$terra_state" in
    missing|legacy) ;;
    *) report_preflight_error "legacy Terra destination is $terra_state and will not be removed: $terra_destination" ;;
  esac
fi

[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: Implementer, reviewer, consultant, and the floor lane exactly match $template_dir; no legacy Terra file remains."
  exit 0
fi

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

same_state Implementer "$implementer_state" "$(classify_current_or_legacy "$implementer_destination" "$implementer_template" '')"
same_state Sol "$sol_state" "$(classify_current_or_legacy "$sol_destination" "$sol_template" "$prev_sol_sha256")"
same_state "Sol consultant" "$consultant_state" "$(classify_current_or_legacy "$consultant_destination" "$consultant_template" '')"
same_state "floor lane" "$floor_state" "$(classify_current_or_legacy "$floor_destination" "$floor_template" '')"
same_state "legacy Terra" "$terra_state" "$(classify_legacy_terra "$terra_destination")"

case "$implementer_state" in
  missing) install_missing "$implementer_template" "$implementer_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $implementer_destination" ;;
esac

case "$sol_state" in
  missing) install_missing "$sol_template" "$sol_destination" ;;
  legacy) replace_legacy_sol ;;
  current) printf '%s\n' "ALREADY CURRENT: $sol_destination" ;;
esac

case "$consultant_state" in
  missing) install_missing "$consultant_template" "$consultant_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $consultant_destination" ;;
esac

case "$floor_state" in
  missing) install_missing "$floor_template" "$floor_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $floor_destination" ;;
esac

if [ "$terra_state" = legacy ]; then
  replace_legacy_terra
fi

[ "$(classify_current_or_legacy "$implementer_destination" "$implementer_template" '')" = current ] ||
  fail "post-install exactness check failed: $implementer_destination"
[ "$(classify_current_or_legacy "$sol_destination" "$sol_template" "$prev_sol_sha256")" = current ] ||
  fail "post-install exactness check failed: $sol_destination"
[ "$(classify_current_or_legacy "$consultant_destination" "$consultant_template" '')" = current ] ||
  fail "post-install exactness check failed: $consultant_destination"
[ "$(classify_current_or_legacy "$floor_destination" "$floor_template" '')" = current ] ||
  fail "post-install exactness check failed: $floor_destination"
[ "$(classify_legacy_terra "$terra_destination")" = missing ] ||
  fail "post-install legacy removal check failed: $terra_destination"

printf '%s\n' "INSTALL PASSED: Implementer, reviewer, consultant, and the floor lane exactly match $template_dir; no legacy Terra file remains."
