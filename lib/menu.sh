#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT/BIN_DIR/BOOTSTRAP_HOME from the entrypoint
# Interactive menu. whiptail when available, a numbered text menu otherwise.
# Every action calls the same functions as the CLI; no install logic lives here.

_MENU_BACKEND=''

_menu_dims() {
  local l=24 c=80
  if [[ -t 1 ]]; then
    l=$(tput lines 2>/dev/null) || l=24
    c=$(tput cols 2>/dev/null) || c=80
  fi
  [[ "$l" =~ ^[0-9]+$ ]] || l=24
  [[ "$c" =~ ^[0-9]+$ ]] || c=80
  ((l < 15)) && l=24
  ((c < 60)) && c=80
  ((c > 110)) && c=110
  local list=$((l - 10)); ((list < 5)) && list=5
  printf '%s %s %s\n' "$((l - 4))" "$((c - 4))" "$list"
}

# Returns 0 when whiptail can be used. Offers to install it once.
_menu_ensure_whiptail() {
  command -v whiptail >/dev/null 2>&1 && return 0
  [[ -t 0 && -t 1 ]] || return 1
  [[ ${AIT_MENU_TEXT:-0} == 1 ]] && return 1
  local a
  read -r -p 'whiptail is missing. Install it with sudo apt-get? [y/N] ' a || return 1
  [[ "$a" =~ ^[Yy]$ ]] || return 1
  apt_install whiptail || true
  command -v whiptail >/dev/null 2>&1
}

_menu_init() {
  _MENU_BACKEND=text
  if [[ ${AIT_MENU_TEXT:-0} != 1 ]] && _menu_ensure_whiptail; then
    _MENU_BACKEND=whiptail
  fi
}

_menu_msg() {
  local title=$1 text=$2
  if [[ "$_MENU_BACKEND" == whiptail ]]; then
    local h w _; read -r h w _ < <(_menu_dims)
    whiptail --title "$title" --msgbox "$text" "$h" "$w" 3>&1 1>&2 2>&3
  else
    printf '\n== %s ==\n%s\n' "$title" "$text" >&2
    if [[ -t 0 ]]; then read -r -p 'Press Enter to continue... ' _ || true; fi
  fi
  return 0
}

_menu_yesno() {
  local title=$1 text=$2
  if [[ "$_MENU_BACKEND" == whiptail ]]; then
    local h w _; read -r h w _ < <(_menu_dims)
    whiptail --title "$title" --yesno "$text" "$h" "$w" 3>&1 1>&2 2>&3
    return
  fi
  local a
  printf '\n== %s ==\n%s\n' "$title" "$text" >&2
  read -r -p 'Proceed? [y/N] ' a || return 1
  [[ "$a" =~ ^[Yy]$ ]]
}

# _menu_menu <title> <text> <tag> <label> [<tag> <label> ...] -> prints tag
_menu_menu() {
  local title=$1 text=$2; shift 2
  local -a tags=() labels=()
  while (($# >= 2)); do tags+=("$1"); labels+=("$2"); shift 2; done

  if [[ "$_MENU_BACKEND" == whiptail ]]; then
    local -a args=()
    local i
    for ((i = 0; i < ${#tags[@]}; i++)); do args+=("${tags[$i]}" "${labels[$i]}"); done
    local h w l; read -r h w l < <(_menu_dims)
    whiptail --title "$title" --menu "$text" "$h" "$w" "$l" "${args[@]}" 3>&1 1>&2 2>&3
    return
  fi

  printf '\n== %s ==\n%s\n\n' "$title" "$text" >&2
  local i choice
  for ((i = 0; i < ${#tags[@]}; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${labels[$i]}" >&2
  done
  printf '  0) Back / quit\n' >&2
  read -r -p 'Choice: ' choice || return 1
  [[ -z "$choice" || "$choice" == 0 || "$choice" == q || "$choice" == Q ]] && return 1
  [[ "$choice" =~ ^[0-9]+$ ]] || return 1
  ((choice >= 1 && choice <= ${#tags[@]})) || return 1
  printf '%s\n' "${tags[$((choice - 1))]}"
}

# Catalog rows for a profile, including opt-in tools (unticked by default).
# Emits: category <TAB> name <TAB> ON/OFF <TAB> label
_menu_rows() {
  local profile=$1 tags platform tsv
  tags=$(catalog_profile_tags "$profile" | tr '\n' ' ')
  platform=$(detect_platform)
  tsv=$(catalog_resolve_tsv)
  local name tagcsv optin cat gui platforms _prio _method _deps bin desc status label
  while IFS=$'\t' read -r name tagcsv optin cat gui platforms _prio _method _deps bin desc; do
    [[ -z "$name" ]] && continue
    _tags_intersect "$tagcsv" "$tags" || continue
    _platform_allowed "$platforms" "$platform" || continue

    label="[$cat] $name — $desc"
    command -v "$bin" >/dev/null 2>&1 && label+=' (installed)'
    [[ "$optin" == true ]] && label+=' (opt-in)'
    status=ON
    if [[ "$optin" == true || "$gui" == true ]]; then
      status=OFF
    fi
    if [[ "$gui" == true ]] && is_wsl; then
      label+=' (recommended on Windows)'
      status=OFF
    fi
    printf '%s\t%s\t%s\t%s\n' "$cat" "$name" "$status" "$label"
  done <<< "$tsv" | sort -t$'\t' -k1,1 -k2,2
}

# Numbered text checklist. Prints the selected tool names, space-separated.
_menu_checklist_text() {
  local title=$1 rows=$2
  local -a rowcats=() rownames=() rowlabels=()
  local cat name status label last=''
  while IFS=$'\t' read -r cat name status label; do
    [[ -z "$name" ]] && continue
    rowcats+=("$cat"); rownames+=("$name"); rowlabels+=("$label")
  done <<< "$rows"

  printf '\n== %s ==\n' "$title" >&2
  local i
  for ((i = 0; i < ${#rownames[@]}; i++)); do
    if [[ "${rowcats[$i]}" != "$last" ]]; then
      printf '\n  ── %s ──\n' "${rowcats[$i]}" >&2
      last=${rowcats[$i]}
    fi
    printf '  %2d) %s\n' "$((i + 1))" "${rowlabels[$i]}" >&2
  done

  local answer part lo hi n
  read -r -p 'Select tools (1,3,5-9 | a=all | Enter=back): ' answer || return 1
  [[ -z "$answer" ]] && return 1
  local -a picked=()
  IFS=',' read -ra _parts <<< "$answer"
  for part in "${_parts[@]}"; do
    part=${part// /}
    case "$part" in
      a | A | all)
        for ((n = 1; n <= ${#rownames[@]}; n++)); do picked+=("${rownames[$((n - 1))]}"); done ;;
      *-*)
        lo=${part%-*}; hi=${part#*-}
        [[ "$lo" =~ ^[0-9]+$ && "$hi" =~ ^[0-9]+$ ]] || continue
        for ((n = lo; n <= hi; n++)); do
          ((n >= 1 && n <= ${#rownames[@]})) && picked+=("${rownames[$((n - 1))]}")
        done ;;
      *)
        [[ "$part" =~ ^[0-9]+$ ]] || continue
        ((part >= 1 && part <= ${#rownames[@]})) && picked+=("${rownames[$((part - 1))]}")
        ;;
    esac
  done
  ((${#picked[@]})) || return 1
  printf '%s ' "${picked[@]}"
  printf '\n'
}

_menu_checklist() {
  local title=$1 rows=$2
  if [[ "$_MENU_BACKEND" != whiptail ]]; then
    _menu_checklist_text "$title" "$rows"
    return
  fi
  local -a args=()
  local cat name status label
  while IFS=$'\t' read -r cat name status label; do
    [[ -z "$name" ]] && continue
    args+=("$name" "$label" "$status")
  done <<< "$rows"
  local h w l; read -r h w l < <(_menu_dims)
  # --separate-output prints one bare tag per line (no quoting), so names with
  # spaces or shell metacharacters survive the round trip untouched.
  whiptail --title "$title" \
    --separate-output \
    --checklist 'Space selects · Enter installs · Esc goes back' \
    "$h" "$w" "$l" "${args[@]}" 3>&1 1>&2 2>&3
}

# Summarise an explicit list: count and whether sudo is needed.
_menu_summary() {
  local -a names=("$@")
  local tsv name tagcsv optin cat gui platforms _prio method deps bin desc
  local sudo=no
  tsv=$(catalog_resolve_tsv)
  while IFS=$'\t' read -r name tagcsv optin cat gui platforms _ method deps bin desc; do
    [[ -z "$name" ]] && continue
    local sought=0 n
    for n in "${names[@]}"; do [[ "$n" == "$name" ]] && sought=1; done
    ((sought)) || continue
    [[ "$method" == apt || "$deps" == 1 ]] && sudo=yes
  done <<< "$tsv"
  printf 'Tools selected: %d\nSudo needed: %s\n\n' "${#names[@]}" "$sudo"
  printf '%s\n' "${names[@]}"
}

_menu_confirm_names() {
  local label=$1; shift
  local text; text=$(_menu_summary "$@")
  _menu_yesno "$label" "$text
Proceed with installation?"
}

_menu_select() {
  local profile=$1 label=$2
  local rows chosen
  rows=$(_menu_rows "$profile")
  if [[ -z "$rows" ]]; then
    _menu_msg "$label" 'No tools available for this profile on this platform.'
    return 0
  fi
  chosen=$(_menu_checklist "Select $label tools" "$rows") || return 0
  local -a names=()
  read -ra names <<< "$chosen"
  ((${#names[@]})) || { _menu_msg "$label" 'No tools selected.'; return 0; }
  _menu_confirm_names "$label" "${names[@]}" || return 0
  # Keep the real profile name so the failure retry hint is a valid command.
  ait_install_names "$profile" "${names[@]}"
  _menu_msg 'Installation finished' 'Review the output above. Run ait doctor to verify the tools.'
}

_menu_profile() {
  local profile=$1 label=$2 choice
  while :; do
    choice=$(_menu_menu "$label" 'Install every tool in this profile, or pick individual tools?' \
      all 'Install all tools in this profile' \
      select 'Select tools') || return 0
    case "$choice" in
      all)
        local names count
        names=$(resolve_tools "$profile" '' '')
        count=$(grep -c . <<< "$names" || true)
        if _menu_yesno "$label" "Install all $count tools in the '$profile' profile?
Some need sudo for system packages."; then
          ait_install --profile "$profile" --yes
          _menu_msg 'Installation finished' 'Review the output above. Run ait doctor to verify the tools.'
        fi
        ;;
      select) _menu_select "$profile" "$label" ;;
    esac
  done
}

_menu_update() {
  manifest_init
  local list count
  list=$(manifest_tools)
  count=$(grep -c . <<< "$list" || true)
  if [[ -z "$list" || "$count" == 0 ]]; then
    _menu_msg 'Update' 'Nothing has been installed by AutoInstallTools yet.'
    return 0
  fi
  if _menu_yesno 'Update existing tools' "Update the $count tool(s) recorded in the manifest?
Also refreshes nuclei templates and wordlists."; then
    ait_update
  fi
}

_menu_wsl_net() {
  if ! declare -F wsl_net_toggle >/dev/null 2>&1; then
    _menu_msg 'WSL networking' 'The WSL networking helper is not available in this build.'
    return 0
  fi
  local label
  label=$(wsl_net_menu_label)
  if _menu_yesno 'WSL networking' "$label

Toggle the mode? Your .wslconfig is backed up and only networkingMode is changed.
The change applies after: wsl --shutdown"; then
    wsl_net_toggle
  fi
}

menu_main() {
  require_linux
  bootstrap_yq
  _menu_init
  local choice wsl_item
  while :; do
    if is_wsl; then
      wsl_item=$(wsl_net_menu_label 2>/dev/null || echo 'WSL networking: unavailable')
    fi
    if is_wsl; then
      choice=$(_menu_menu 'AutoInstallTools' 'Set up your web + mobile AppSec workstation' \
        mobile 'Install Mobile AppSec tools' \
        web 'Install Web AppSec tools' \
        all 'Install All tools' \
        update 'Update existing tools' \
        wsl "$wsl_item" \
        quit 'Quit') || break
    else
      choice=$(_menu_menu 'AutoInstallTools' 'Set up your web + mobile AppSec workstation' \
        mobile 'Install Mobile AppSec tools' \
        web 'Install Web AppSec tools' \
        all 'Install All tools' \
        update 'Update existing tools' \
        quit 'Quit') || break
    fi
    case "$choice" in
      mobile) _menu_profile mobile 'Mobile AppSec tools' ;;
      web) _menu_profile web 'Web AppSec tools' ;;
      all)
        if _menu_yesno 'Install all tools' 'Install every default tool (profiles all)?
Some need sudo for system packages; GUI tools are skipped on a VPS.'; then
          ait_install --profile all --yes
          _menu_msg 'Installation finished' 'Review the output above. Run ait doctor to verify the tools.'
        fi
        ;;
      update) _menu_update ;;
      wsl) _menu_wsl_net ;;
      quit) break ;;
    esac
  done
  return 0
}
