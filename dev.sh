#!/bin/bash
# Shell function for managing git repositories and code projects

# Function to check for updates
check_for_updates() {
  local script_path="${BASH_SOURCE[0]}"
  local script_dir
  script_dir=$(cd "$(dirname "$script_path")" && pwd)

  # If script_dir doesn't contain "microdev", assume it's $HOME/workspace/microdev/
  if [[ "$script_dir" != *"microdev"* ]]; then
    script_dir="$HOME/workspace/microdev"
  fi

  # Check if there's a remote repository for this script
  if [ -d "$script_dir/.git" ]; then
    local current_branch=$(git -C "$script_dir" branch --show-current 2>/dev/null || echo "main")
    local remote_url=$(git -C "$script_dir" config --get remote.origin.url 2>/dev/null)

    if [ -n "$remote_url" ]; then
      # Check if we should pull today (only once per day)
      local last_pull_file="$script_dir/.last_pull"
      local today=$(date +%Y-%m-%d)
      local last_pull_date=""

      if [ -f "$last_pull_file" ]; then
        last_pull_date=$(cat "$last_pull_file")
      fi

      if [ "$today" != "$last_pull_date" ]; then
        echo "Pulling latest changes in $script_dir..."

        # Pull latest changes in background silently
        git -C "$script_dir" pull --quiet >/dev/null 2>&1 &

        # Record today's date
        echo "$today" > "$last_pull_file"

        echo "Latest changes pulled."
      fi
    fi
  fi
}

dev() {
  check_for_updates
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
  elif [ "$1" = "new" ]; then
    shift # Remove "new" from arguments
    local dir_name="$1"
    if [ -z "$dir_name" ]; then
      echo "Usage: dev new <directory_name>"
      return 1
    fi

    local target_dir="$HOME/workspace/$dir_name"

    # Check if directory already exists
    if [ -d "$target_dir" ]; then
      echo "Error: Directory $target_dir already exists."
      return 1
    else
      # Create the directory
      mkdir -p "$target_dir"
      if [ $? -eq 0 ]; then
        cd "$target_dir"
        git init
        if [ $? -eq 0 ]; then
          echo "--> Created and initialized git repo in $(pwd)"
        else
          echo "Error: Failed to initialize git repository."
          return 1
        fi
      else
        echo "Error: Failed to create directory."
        return 1
      fi
    fi
  elif [ "$1" = "install" ]; then
    # Create workspace directory if it doesn't exist
    if [ ! -d "$HOME/workspace" ]; then
      mkdir -p "$HOME/workspace"
      echo "Created workspace directory at $HOME/workspace"
    fi

    # Clone microdev repository
    local microdev_repo="https://github.com/XanderStrike/microdev.git"
    local microdev_dir="$HOME/workspace/microdev"

    if [ ! -d "$microdev_dir" ]; then
      echo "Cloning microdev repository..."
      git clone "$microdev_repo" "$microdev_dir"
      if [ $? -ne 0 ]; then
        echo "Error: Failed to clone microdev repository."
        return 1
      fi
    else
      echo "microdev repository already exists at $microdev_dir"
    fi

    # Source the dev.sh script from the appropriate profile file
    local profile_file=""
    if [ -f "$HOME/.bashrc" ]; then
      profile_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      profile_file="$HOME/.bash_profile"
    elif [ -f "$HOME/.profile" ]; then
      profile_file="$HOME/.profile"
    elif [ -f "$HOME/.zprofile" ]; then
      profile_file="$HOME/.zprofile"
    else
      echo "Error: Could not find .bashrc, .bash_profile, .profile, or .zprofile"
      return 1
    fi

    # Check if the source command already exists in the profile file
    local source_line="source $microdev_dir/dev.sh"
    if ! grep -qF "$source_line" "$profile_file"; then
      echo "Adding source command to $profile_file"
      echo "" >> "$profile_file"
      echo "# Source microdev dev.sh" >> "$profile_file"
      echo "$source_line" >> "$profile_file"
    else
      echo "Source command already exists in $profile_file"
    fi

    echo "Installation complete. Please restart your shell or run 'source $profile_file' to use the dev command."
  else
    # Allow for future 'dev' subcommands
    if [ -n "$1" ]; then
        echo "Error: Unknown dev command '$1'."
    fi
    echo "Usage: dev [command]"
    echo "Available commands:"
    echo "  cd <directory_name>    - Change to the specified directory in predefined locations."
    echo "  clone <github_url>     - Clone a GitHub repository into ~/workspace/ and change directory."
    echo "  new <directory_name>   - Create a new directory in ~/workspace/, change to it, and initialize a git repository."
    echo "  install                - Install microdev by cloning the repository and setting up the dev command."
    return 1
  fi
}

# Handle direct script invocation with arguments
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Script is being sourced, use the function as-is
  :
else
  # Script is being executed directly, call the function with all arguments
  dev "$@"
fi
