#!/bin/bash
# Shell function to quickly change directory to predefined project locations

dev() {
  if [ "$1" = "cd" ]; then
    shift # Remove "cd" from arguments
    local target_dir_name="$1"
    local search_paths=("$HOME/config" "$HOME/configs" "$HOME/workspace") # Add more paths here if needed

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

    local resolved_search_root

    for search_root_orig in "${search_paths[@]}"; do
      # Resolve the search_root_orig to its canonical, absolute path.
      # This handles cases where search_root_orig is a symlink (e.g., $HOME/config).
      
      resolved_search_root=$(readlink -f "$search_root_orig" 2>/dev/null)

      # If readlink failed or the resolved path is not a directory, skip this search_root_orig.
      if [[ -z "$resolved_search_root" || ! -d "$resolved_search_root" ]]; then
        # Silently skip invalid or non-directory paths.
        continue
      fi

      # Attempt to find a directory matching the partial name within the resolved_search_root.
      # Use -L with find:
      #   - So that if an entry *within* resolved_search_root (at maxdepth 1)
      #     is a symlink to a directory, -type d still considers it a directory, and find lists the symlink path.
      # The -print -quit is a GNU find extension for efficiency.
      local potential_match=$(find -L "$resolved_search_root" -maxdepth 1 -type d -iname "*$target_dir_name*" -print -quit 2>/dev/null)
      
      if [ -n "$potential_match" ] && [ -d "$potential_match" ]; then
        # The [ -d "$potential_match" ] check correctly evaluates to true
        # if $potential_match is a directory OR a symlink to a directory.
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
  elif [ "$1" = "clone" ]; then
    shift # Remove "clone" from arguments
    local github_url="$1"
    if [ -z "$github_url" ]; then
      echo "Usage: dev clone <github_url>"
      return 1
    fi

    # Extract repository name from URL
    local repo_name=$(basename "$github_url" .git)
    local target_dir="$HOME/workspace/$repo_name"

    # Check if directory already exists
    if [ -d "$target_dir" ]; then
      echo "Directory $target_dir already exists. Changing to it."
      cd "$target_dir"
    else
      # Clone the repository
      git clone "$github_url" "$target_dir"
      if [ $? -eq 0 ]; then
        cd "$target_dir"
        echo "--> Cloned and switched to $(pwd)"
      else
        echo "Error: Failed to clone repository."
        return 1
      fi
    fi
  else
    # Allow for future 'dev' subcommands
    if [ -n "$1" ]; then
        echo "Error: Unknown dev command '$1'."
    fi
    echo "Usage: dev [command]"
    echo "Available commands:"
    echo "  cd <directory_name>    - Change to the specified directory in predefined locations."
    echo "  clone <github_url>     - Clone a GitHub repository into ~/workspace/ and change directory."
    return 1
  fi
}

# Optional: You could add an alias for convenience if you always type `dev cd`
# alias dcd='dev cd'

# To make this command available, add the following line to your ~/.bashrc or ~/.zshrc:
# source /Users/xander/workspace/microdev/dev_cd_function.sh
