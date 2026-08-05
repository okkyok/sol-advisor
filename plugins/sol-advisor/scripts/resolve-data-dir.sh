#!/bin/sh

resolve_data_dir() {
  resolve_data_dir_override=$1
  resolve_data_dir_target=$2
  resolved_data_dir=
  resolved_data_candidates=
  resolved_data_candidate_count=0
  resolved_data_file_found=0

  resolve_data_dir_consider() {
    resolve_data_dir_candidate=$1
    if [ "$resolved_data_candidate_count" -eq 0 ]; then
      resolved_data_candidates=$resolve_data_dir_candidate
      resolved_data_dir=$resolve_data_dir_candidate
    else
      resolved_data_candidates=$resolved_data_candidates'
'$resolve_data_dir_candidate
    fi
    resolved_data_candidate_count=$((resolved_data_candidate_count + 1))
    if [ -r "$resolve_data_dir_candidate/$resolve_data_dir_target" ]; then
      resolved_data_dir=$resolve_data_dir_candidate
      resolved_data_file_found=1
    fi
  }

  if [ -n "$resolve_data_dir_override" ]; then
    resolve_data_dir_consider "$resolve_data_dir_override"
  fi
  if [ "$resolved_data_file_found" -eq 0 ] && [ -n "${PLUGIN_DATA:-}" ]; then
    resolve_data_dir_consider "$PLUGIN_DATA"
  fi
  if [ "$resolved_data_file_found" -eq 0 ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    resolve_data_dir_consider "$CLAUDE_PLUGIN_DATA"
  fi

  if [ "$resolved_data_file_found" -eq 0 ]; then
    # Because this file is sourced, $0 names the caller. Both callers live in
    # scripts/, so this is also equivalent to resolving this helper directory.
    if resolve_data_dir_script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd); then
      resolve_data_dir_plugin_root=$(dirname "$resolve_data_dir_script_dir")
      resolve_data_dir_plugin_dir=$(dirname "$resolve_data_dir_plugin_root")
      resolve_data_dir_marketplace_dir=$(dirname "$resolve_data_dir_plugin_dir")
      resolve_data_dir_cache_root=$(dirname "$resolve_data_dir_marketplace_dir")
      resolve_data_dir_plugins_root=$(dirname "$resolve_data_dir_cache_root")
      if [ "$(basename "$resolve_data_dir_plugins_root")" = plugins ]; then
        resolve_data_dir_plugin_name=$(basename "$resolve_data_dir_plugin_dir")
        resolve_data_dir_marketplace=$(basename "$resolve_data_dir_marketplace_dir")
        resolve_data_dir_consider "$resolve_data_dir_plugins_root/data/$resolve_data_dir_marketplace-$resolve_data_dir_plugin_name"
      fi
    fi
  fi

  if [ "$resolved_data_file_found" -eq 0 ]; then
    # A repository checkout has the stable shape
    # <checkout-root>/plugins/<plugin>/scripts. Its plugin data remains in the
    # installed marketplace data directory, named after the checkout root.
    if [ -n "${resolve_data_dir_plugin_root:-}" ]; then
      resolve_data_dir_plugins_dir=$(dirname "$resolve_data_dir_plugin_root")
      if [ "$(basename "$resolve_data_dir_plugins_dir")" = plugins ]; then
        resolve_data_dir_checkout_root=$(dirname "$resolve_data_dir_plugins_dir")
        resolve_data_dir_checkout=$(basename "$resolve_data_dir_checkout_root")
        resolve_data_dir_plugin_name=$(basename "$resolve_data_dir_plugin_root")
        resolve_data_dir_checkout_candidate="${CODEX_HOME:-$HOME/.codex}/plugins/data/$resolve_data_dir_checkout-$resolve_data_dir_plugin_name"
        resolve_data_dir_consider "$resolve_data_dir_checkout_candidate"
      fi
    fi
  fi

  if [ "$resolved_data_file_found" -eq 0 ]; then
    resolve_data_dir_consider "${CODEX_HOME:-$HOME/.codex}/sol-advisor"
  fi
}
