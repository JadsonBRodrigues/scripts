#!/bin/bash

# ------------------------------------------------------------------
# SINCRO FOLDERS MANAGER
#
# Creates and manages folders used to store status screenshots
# (evidence) of SINCRO devices.
#
# Folder name pattern:
#   SINCRO <type> - <device> (<STATUS>)
#   Example: SINCRO 1 - 15 (OK)
#     type   = 1 or 2
#     device = device number or name (e.g. 15, 16, 16b17)
#     STATUS = OK, PENDING, FINISHED, ...
#
# Requirements: Bash (Git Bash on Windows, Linux or WSL)
#
# How to use:
#   1. Copy this script to the folder where the SINCRO folders
#      should be created.
#   2. Run: bash folders_for_sincro_monitoring.sh
#   3. Menu options:
#      1) Create folders - choose the type (1 or 2), how many
#         folders and the first device number. New folders are
#         created with the status PENDING.
#      2) Edit folder    - pick a folder from the list, then type
#         the new type, device or status. Press Enter to keep
#         the current value.
#      3) Delete folder  - pick a folder from the list and confirm
#         with y. Deletion is permanent (no recycle bin).
#      4) List folders   - show all SINCRO folders.
#      0) Exit
#
# Notes:
#   - The list number (1, 2, 3...) is only the position in the
#     list, it is NOT the device number.
#   - Allowed characters in device and status: letters, numbers,
#     space and . _ + -
#   - The status is always saved in uppercase.
#   - Two folders cannot have the same type and device.
# ------------------------------------------------------------------



BASE_DIR="."
DEFAULT_STATUS="PENDING"
PATTERN='^SINCRO ([12]) - (.+) \((.+)\)$'
VALID_TEXT='^[A-Za-z0-9_. +-]+$'

# Fill the global array FOLDERS with all SINCRO folders
load_folders() {
  FOLDERS=()
  local d
  while IFS= read -r d; do
    FOLDERS+=("$d")
  done < <(find "$BASE_DIR" -maxdepth 1 -type d -name 'SINCRO *' -printf '%f\n' | sort -V)
}

list_folders() {
  load_folders
  if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "No SINCRO folders found."
    return 1
  fi
  local i=1 f
  for f in "${FOLDERS[@]}"; do
    echo "$i) $f"
    ((i++))
  done
}

ask_type() {
  local t
  while true; do
    read -rp "Sincro type (1 or 2): " t
    if [[ "$t" == "1" || "$t" == "2" ]]; then
      TYPE="$t"
      return
    fi
    echo "Invalid, type 1 or 2."
  done
}

create_folders() {
  ask_type
  read -rp "How many folders to create? " total
  read -rp "First device number (e.g. 1): " start
  if ! [[ "$total" =~ ^[0-9]+$ && "$start" =~ ^[0-9]+$ ]]; then
    echo "Numbers only."
    return
  fi
  local i dev name
  for ((i=0; i<total; i++)); do
    dev=$((10#$start + i))
    name="SINCRO $TYPE - $dev ($DEFAULT_STATUS)"
    if compgen -G "$BASE_DIR/SINCRO $TYPE - $dev (*)" > /dev/null; then
      echo "Skipping, already exists: SINCRO $TYPE - $dev"
    else
      mkdir "$BASE_DIR/$name"
      echo "Created: $name"
    fi
  done
}

pick_folder() {
  list_folders || return 1
  read -rp "Folder number from the list - empty to exit: " n
  [[ -z "$n" ]] && return 1
  if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > ${#FOLDERS[@]} )); then
    echo "Invalid number."
    return 1
  fi
  PICKED="${FOLDERS[$((n-1))]}"
}

edit_folder() {
  pick_folder || return
  local old="$PICKED"
  if ! [[ "$old" =~ $PATTERN ]]; then
    echo "Folder name does not match the pattern."
    return
  fi
  local type="${BASH_REMATCH[1]}"
  local dev="${BASH_REMATCH[2]}"
  local status="${BASH_REMATCH[3]}"
  echo "Current: type=$type | device=$dev | status=$status"

  read -rp "New type 1/2 [Enter = keep]: " v
  if [[ -n "$v" ]]; then
    if [[ "$v" == "1" || "$v" == "2" ]]; then
      type="$v"
    else
      echo "Invalid type."
      return
    fi
  fi

  read -rp "New device (e.g. 15, 16b17) [Enter = keep]: " v
  if [[ -n "$v" ]]; then
    if [[ "$v" =~ $VALID_TEXT ]]; then
      dev="$v"
    else
      echo "Use only letters, numbers, space and . _ + -"
      return
    fi
  fi

  read -rp "New status (e.g. OK) [Enter = keep]: " v
  if [[ -n "$v" ]]; then
    if [[ "$v" =~ $VALID_TEXT ]]; then
      status="${v^^}"
    else
      echo "Use only letters, numbers, space and . _ + -"
      return
    fi
  fi

  local new="SINCRO $type - $dev ($status)"
  if [[ "$new" == "$old" ]]; then
    echo "Nothing changed."
    return
  fi

  local other
  other=$(compgen -G "$BASE_DIR/SINCRO $type - $dev (*)" | grep -v -F -x "$BASE_DIR/$old" | head -n1)
  if [[ -n "$other" ]]; then
    echo "Already exists: ${other#"$BASE_DIR"/}"
    return
  fi

  mv "$BASE_DIR/$old" "$BASE_DIR/$new"
  echo "Renamed: $new"
}

delete_folder() {
  pick_folder || return
  local old="$PICKED"
  read -rp "Delete '$old' and everything inside it? (y/N) " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm -r "$BASE_DIR/$old"
    echo "Deleted: $old"
  else
    echo "Cancelled."
  fi
}

while true; do
  echo
  echo "1) Create folders"
  echo "2) Edit folder (type / device / status)"
  echo "3) Delete folder"
  echo "4) List folders"
  echo "0) Exit"
  read -rp "Choose an option: " opt
  case "$opt" in
    1) create_folders ;;
    2) edit_folder ;;
    3) delete_folder ;;
    4) list_folders ;;
    0) break ;;
    *) echo "Invalid option." ;;
  esac
done
