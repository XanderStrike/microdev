#!/bin/bash
# Shell function to quickly change directory to predefined project locations

dev() {
  if [ "$1" = "cd" ]; then
    shift # Remove "cd" from arguments
    local target_dir_name="$1"
    local search_paths=("$HOME/config" "$HOME/workspace") # Add more paths here if needed

    if [ -z "$target_dir_name" ]; then
      echo "Usage: dev cd <directory_name>"
      echo "Searches for <directory_name> in:"
      for p in "${search_paths[@]}"; do
        echo "  - $p/"
      done
      return 1
    fi

    local found_path=""

    # Expand ~ to the full home directory path
    local home_dir="$HOME"

    for base_path in "${search_paths[@]}"; do
      # Attempt to find a directory matching the partial name
      # -maxdepth 1 ensures we only search direct children of base_path
      # -type d specifies that we are looking for directories
      # -iname makes the search case-insensitive for the target_dir_name
      # head -n 1 takes the first match if multiple exist
      local potential_match=$(find "$base_path" -maxdepth 1 -type d -iname "*$target_dir_name*" -print -quit 2>/dev/null)
      
      if [ -n "$potential_match" ] && [ -d "$potential_match" ]; then
        found_path="$potential_match"
        break 
      fi
    done

    if [ -n "$found_path" ]; then
      cd "$found_path" && echo "--> Switched to $(pwd)"
    else
      echo "Error: Directory matching '$target_dir_name' not found within the following searched locations:"
      for p in "${search_paths[@]}"; do
        echo "  - $p/*$target_dir_name*"
      done
      return 1
    fi
  else
    # Allow for future 'dev' subcommands
    if [ -n "$1" ]; then
        echo "Error: Unknown dev command '$1'."
    fi
    echo "Usage: dev cd <directory_name>"
    echo "Available commands:"
    echo "  cd <directory_name>  - Change to the specified directory in predefined locations."
    return 1
  fi
}

# Optional: You could add an alias for convenience if you always type `dev cd`
# alias dcd='dev cd'

# To make this command available, add the following line to your ~/.bashrc or ~/.zshrc:
# source /Users/xander/workspace/microdev/dev_cd_function.sh
