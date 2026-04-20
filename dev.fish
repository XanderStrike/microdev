# microdev - fish shell implementation
# https://github.com/XanderStrike/microdev

function dev
    set -l search_paths "$HOME/config" "$HOME/configs" "$HOME/workspace"

    # Check for updates
    _microdev_check_updates

    switch "$argv[1]"
        case cd
            if test (count $argv) -lt 2
                echo "Usage: dev cd <directory_name>"
                echo "Searches for <directory_name> in:"
                for p in $search_paths
                    echo "  - $p/"
                end
                return 1
            end

            set -l target_dir_name $argv[2]
            set -l found_path ""

            for search_root_orig in $search_paths
                set -l resolved_search_root (readlink -f "$search_root_orig" 2>/dev/null)

                if test -z "$resolved_search_root"; or not test -d "$resolved_search_root"
                    continue
                end

                set -l potential_match (find -L "$resolved_search_root" -maxdepth 1 -type d -iname "*$target_dir_name*" -print -quit 2>/dev/null)

                if test -n "$potential_match"; and test -d "$potential_match"
                    set found_path "$potential_match"
                    break
                end
            end

            if test -n "$found_path"
                cd "$found_path"
                echo "--> Switched to "(pwd)
            else
                echo "Error: Directory matching '$target_dir_name' not found within the following searched locations:"
                for p in $search_paths
                    echo "  - $p/*$target_dir_name*"
                end
                return 1
            end

        case clone
            if test (count $argv) -lt 2
                echo "Usage: dev clone <github_url>"
                return 1
            end

            set -l github_url $argv[2]
            set -l repo_name (basename "$github_url" .git)
            set -l target_dir "$HOME/workspace/$repo_name"

            if test -d "$target_dir"
                echo "Directory $target_dir already exists. Changing to it."
                cd "$target_dir"
            else
                git clone "$github_url" "$target_dir"
                if test $status -eq 0
                    cd "$target_dir"
                    echo "--> Cloned and switched to "(pwd)
                else
                    echo "Error: Failed to clone repository."
                    return 1
                end
            end

        case new
            if test (count $argv) -lt 2
                echo "Usage: dev new <directory_name>"
                return 1
            end

            set -l dir_name $argv[2]
            set -l target_dir "$HOME/workspace/$dir_name"

            if test -d "$target_dir"
                echo "Error: Directory $target_dir already exists."
                return 1
            else
                mkdir -p "$target_dir"
                if test $status -eq 0
                    cd "$target_dir"
                    git init
                    if test $status -eq 0
                        echo "--> Created and initialized git repo in "(pwd)
                    else
                        echo "Error: Failed to initialize git repository."
                        return 1
                    end
                else
                    echo "Error: Failed to create directory."
                    return 1
                end
            end

        case install
            if not test -d "$HOME/workspace"
                mkdir -p "$HOME/workspace"
                echo "Created workspace directory at $HOME/workspace"
            end

            set -l microdev_repo "https://github.com/XanderStrike/microdev.git"
            set -l microdev_dir "$HOME/workspace/microdev"

            if not test -d "$microdev_dir"
                echo "Cloning microdev repository..."
                git clone "$microdev_repo" "$microdev_dir"
                if test $status -ne 0
                    echo "Error: Failed to clone microdev repository."
                    return 1
                end
            else
                echo "microdev repository already exists at $microdev_dir"
            end

            echo "Installation complete. The dev function is available via fish."

        case ""
            echo "Usage: dev [command]"
            echo "Available commands:"
            echo "  cd <directory_name>    - Change to the specified directory in predefined locations."
            echo "  clone <github_url>     - Clone a GitHub repository into ~/workspace/ and change directory."
            echo "  new <directory_name>   - Create a new directory in ~/workspace/, change to it, and initialize a git repository."
            echo "  install                - Install microdev by cloning the repository and setting up the dev command."
            return 1

        case "*"
            echo "Error: Unknown dev command '$argv[1]'."
            echo "Usage: dev [command]"
            echo "Available commands:"
            echo "  cd <directory_name>    - Change to the specified directory in predefined locations."
            echo "  clone <github_url>     - Clone a GitHub repository into ~/workspace/ and change directory."
            echo "  new <directory_name>   - Create a new directory in ~/workspace/, change to it, and initialize a git repository."
            echo "  install                - Install microdev by cloning the repository and setting up the dev command."
            return 1
    end
end

function _microdev_check_updates
    set -l microdev_dir "$HOME/workspace/microdev"

    if not test -d "$microdev_dir/.git"
        return
    end

    set -l remote_url (git -C "$microdev_dir" config --get remote.origin.url 2>/dev/null)
    if test -z "$remote_url"
        return
    end

    set -l last_pull_file "$microdev_dir/.last_pull"
    set -l today (date +%Y-%m-%d)
    set -l last_pull_date ""

    if test -f "$last_pull_file"
        set last_pull_date (cat "$last_pull_file")
    end

    if test "$today" != "$last_pull_date"
        echo "Pulling latest changes in $microdev_dir..."
        git -C "$microdev_dir" pull --quiet >/dev/null 2>&1 &
        echo "$today" > "$last_pull_file"
        echo "Latest changes pulled."
    end
end
