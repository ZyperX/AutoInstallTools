#!/usr/bin/env bash
[[ "$PROFILE" == minimal ]] && return 0
log 'AI CLI clients were installed in the development module when their package registries are available.'
warn 'Configure API keys yourself; this bootstrap never stores credentials.'
