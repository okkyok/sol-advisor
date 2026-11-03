#!/bin/sh
# Install Sol Advisor's shipped custom-agent templates without changing Codex config.
set -eu

usage() {
  cat <<'USAGE'
Usage: install-agents.sh [--target-dir PATH] [--check]

Install Sol Advisor's six current custom-agent templates into the target directory.
Recognized historical versions are replaced and exact retired Terra and Sol consultant
files are removed. Modified, nonregular, or symlinked destinations are refused.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --check            Verify that all six templates match exactly and retired files are absent.
  --help             Show this help text.
USAGE
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
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
  legacy_digests=$3

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    digest=$(sha256_file "$destination")
    legacy_match=0
    for accepted_digest in $legacy_digests; do
      if [ "$digest" = "$accepted_digest" ]; then
        legacy_match=1
        break
      fi
    done

    if [ "$legacy_match" -eq 1 ]; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

classify_retired() {
  destination=$1
  digests=$2

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    match=0
    for accepted_digest in $digests; do
      if [ "$digest" = "$accepted_digest" ]; then
        match=1
        break
      fi
    done

    if [ "$match" -eq 1 ]; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

legacy_digests_for() {
  case "$1" in
    sol-advisor-luna-committer.toml)
      printf '%s' "$legacy_committer"
      ;;
    sol-advisor-luna-implementer.toml)
      printf '%s' "$legacy_implementer"
      ;;
    sol-advisor-sol-reviewer.toml)
      printf '%s' "$legacy_reviewer"
      ;;
    sol-advisor-sol-worker.toml)
      printf '%s' "$legacy_worker"
      ;;
    sol-advisor-luna-deep.toml)
      printf '%s' "$legacy_deep"
      ;;
    sol-advisor-astra-consultant.toml)
      printf '%s' "$legacy_astra"
      ;;
    *)
      printf '%s' ''
      ;;
  esac
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

check_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "--target-dir requires a path."
      case "$2" in
        --*)
          fail "target path must be explicit."
          ;;
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
      fail "unknown argument: $1"
      ;;
  esac
done

case "$target_dir" in
  /*)
    ;;
  *)
    target_dir=$(pwd -P)/$target_dir
    ;;
esac

case "$target_dir" in
  /|//)
    fail "refusing to use filesystem root as target."
    ;;
esac

files='sol-advisor-luna-committer.toml sol-advisor-luna-implementer.toml sol-advisor-luna-deep.toml sol-advisor-sol-worker.toml sol-advisor-sol-reviewer.toml sol-advisor-astra-consultant.toml'
legacy_committer='81a7cd5d89e844f87626e2da7b25a3287bfcf2ee6b25f71f3c388fbb06e292d5 c325b3f14c41abf60fc3830bc823f945e87c2b03aa0deff8749f9fc6fb46d025'
legacy_implementer='e00fd54691d013b9932be714476c141e848951a1c33e9a276ab0d4cd103bba60 a438f5f44cb6430c55e67776b57438943e8ae66e9e3ce46fefeb2eeb30394057 fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb'
legacy_reviewer='6832238b7a45d5761a0a108d1f35f1ea916a248382d9e565cbc6d6abf1e40021 680e33c764c394f3a5311103335ed89b634a0561978eb8836ad2c5f22a690919 095df7967844989b36fa27e1511318406ce3064279a67f6bdf61efc85160d059 ab8f81043bdbafc027e67d436f2e04b004bfab7be8964d1acb57ae3895edc78d b2e492c2c237ce22d7b8137430afb51325671d503b1e4aa1801eb702d03ffb62 0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'
legacy_astra='13b69b27e5a6313c221a96f3e847e9f94a06dfc83d37bafdfd3875a1f4c9a2e0'
legacy_terra='06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d'
legacy_sol_consultant=sol-advisor-sol-consultant.toml
legacy_terra_file=sol-advisor-terra-implementer.toml
legacy_consultant_digests='9aa471a58979238ecb0073a0c3a8f770ae90415f7ead8b62f92136567456fde9 72b970389aa8ef50e601db06982024fcb4bb9781671385eb3d9af48ae55751b2'
legacy_deep=''
legacy_worker=''

if [ -L "$target_dir" ] || { [ -e "$target_dir" ] && [ ! -d "$target_dir" ]; }; then
  fail "target directory is not a real directory: $target_dir"
fi

for f in $files; do
  [ -f "$template_dir/$f" ] && [ ! -L "$template_dir/$f" ] || fail "missing template: $template_dir/$f"
done

[ -e "$target_dir" ] || [ "$check_only" -eq 0 ] || fail "target directory is missing: $target_dir"

failed=0
for f in $files; do
  state=$(classify_current_or_legacy "$target_dir/$f" "$template_dir/$f" "$(legacy_digests_for "$f")")

  if [ "$check_only" -eq 1 ]; then
    if [ "$state" != current ]; then
      printf '%s\n' "ERROR: $f is $state, not current." >&2
      failed=1
    fi
  else
    case "$state" in
      current|missing|legacy)
        ;;
      *)
        printf '%s\n' "ERROR: $f is $state and will not be changed." >&2
        failed=1
        ;;
    esac
  fi
done

retired_consultant=$(classify_retired "$target_dir/$legacy_sol_consultant" "$legacy_consultant_digests")
retired_terra=$(classify_retired "$target_dir/$legacy_terra_file" "$legacy_terra")

if [ "$check_only" -eq 1 ]; then
  if [ "$retired_consultant" != missing ]; then
    printf '%s\n' 'ERROR: retired Sol consultant remains or is unsafe.' >&2
    failed=1
  fi
  if [ "$retired_terra" != missing ]; then
    printf '%s\n' 'ERROR: legacy Terra file remains or is unsafe.' >&2
    failed=1
  fi
else
  case "$retired_consultant" in
    missing|legacy)
      ;;
    *)
      printf '%s\n' 'ERROR: retired Sol consultant is modified or unsafe.' >&2
      failed=1
      ;;
  esac
  case "$retired_terra" in
    missing|legacy)
      ;;
    *)
      printf '%s\n' 'ERROR: legacy Terra file is modified or unsafe.' >&2
      failed=1
      ;;
  esac
fi

[ "$failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  printf '%s\n' 'CHECK PASSED: six templates match; retired files are absent.'
  exit 0
fi

mkdir -p "$target_dir"
for f in $files; do
  dest=$target_dir/$f
  state=$(classify_current_or_legacy "$dest" "$template_dir/$f" "$(legacy_digests_for "$f")")

  if [ "$state" = current ]; then
    printf '%s\n' "ALREADY CURRENT: $dest"
  else
    tmp=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage $dest"
    cp "$template_dir/$f" "$tmp" || {
      rm -f "$tmp"
      fail "could not stage $dest"
    }

    if [ "$state" = missing ]; then
      ln "$tmp" "$dest" || {
        rm -f "$tmp"
        fail "destination changed and will not be overwritten: $dest"
      }
      rm -f "$tmp" || fail "could not remove staged template: $tmp"
    else
      if [ "$(classify_current_or_legacy "$dest" "$template_dir/$f" "$(legacy_digests_for "$f")")" != legacy ]; then
        rm -f "$tmp"
        fail "legacy destination changed and will not be replaced: $dest"
      fi
      mv -f "$tmp" "$dest" || fail "could not replace $dest"
    fi

    printf '%s\n' "INSTALLED: $dest"
  fi
done

if [ "$retired_consultant" = legacy ]; then
  if [ "$(classify_retired "$target_dir/$legacy_sol_consultant" "$legacy_consultant_digests")" != legacy ]; then
    fail "retired Sol consultant changed after preflight: $target_dir/$legacy_sol_consultant"
  fi
  rm "$target_dir/$legacy_sol_consultant" || fail \
    "could not remove retired Sol consultant: $target_dir/$legacy_sol_consultant"
fi

if [ "$retired_terra" = legacy ]; then
  if [ "$(classify_retired "$target_dir/$legacy_terra_file" "$legacy_terra")" != legacy ]; then
    fail "legacy Terra file changed after preflight: $target_dir/$legacy_terra_file"
  fi
  rm "$target_dir/$legacy_terra_file" || fail \
    "could not remove legacy Terra file: $target_dir/$legacy_terra_file"
fi

for f in $files; do
  state=$(classify_current_or_legacy "$target_dir/$f" "$template_dir/$f" "$(legacy_digests_for "$f")")
  [ "$state" = current ] || fail "post-install check failed: $f"
done

printf '%s\n' 'INSTALL PASSED: six templates match; retired files are absent.'
