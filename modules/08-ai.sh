#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
[[ "$PROFILE" != full ]] && return 0
log 'AI CLI clients were installed in the development module when their package registries are available.'
warn 'Configure API keys yourself; this bootstrap never stores credentials.'
