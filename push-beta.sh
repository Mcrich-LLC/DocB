#!/bin/bash

# Set Script Variables
project="Apple Documentation.xcodeproj"
target="Developer Documentation"
branch="beta"  # Default branch
dry_run=false  # Default dry run setting

# Function to get the version number from the Xcode project
getVersion() {
    xcodeproj=$1
    target=$2
    # Command to extract the version number from the Xcode project
    version=$(xcrun xcodebuild -project "$xcodeproj" -target "$target" -showBuildSettings | grep "MARKETING_VERSION" | awk '{print $3}')
    
    # Output the message to the terminal without altering $version
    echo "Project Version: $version"
}

# Function to get the current build number from the Xcode project
getOldBuild() {
    xcodeproj=$1
    # Replace with appropriate command to extract build number from Xcode project
    build_number=$(agvtool what-version | grep -o '[0-9]\+')
    echo "Previous Project Build Number: $build_number"
}

getBuild() {
    xcodeproj=$1
    # Replace with appropriate command to extract build number from Xcode project
    build_number=$(agvtool what-version | grep -o '[0-9]\+')
    echo "Project Build Number: $build_number"
}

# Function to update the version number
updateVersion() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <path_to_pbxproj> <new_marketing_version>"
        exit 1
    fi

    new_version="$1"
    pbxproj_file="$2/project.pbxproj"

    # Check if the file exists
    if [ ! -f "$pbxproj_file" ]; then
        echo "Error: File '$pbxproj_file' not found."
        exit 1
    fi

    # Update MARKETING_VERSION
    echo "Updating MARKETING_VERSION to '$new_version' in '$pbxproj_file'..."
    sed -i "" "s/\(MARKETING_VERSION = \).*/\1$new_version;/g" "$pbxproj_file"

    # Verify if the update was successful
    if grep -q "MARKETING_VERSION = $new_version;" "$pbxproj_file"; then
        echo "Successfully updated MARKETING_VERSION to '$new_version'."
    else
        echo "Error: Failed to update MARKETING_VERSION."
    fi
}

# Function to increment the build number
increment_build_number() {
    build_number=$1
    xcodeproj=$2
    # Increment the build number and update the Xcode project
    agvtool new-version -all $build_number
}

# Parse command-line arguments
while getopts "b:v:d-:" opt; do
    case "${opt}" in
        -)
            case "${OPTARG}" in
                branch=*)
                    branch="${OPTARG#*=}"
                    ;;
                build-number=*)
                    build_number="${OPTARG#*=}"
                    build_number_provided=true
                    ;;
                build=*)
                    build_number="${OPTARG#*=}"
                    build_number_provided=true
                    ;;
                version=*)
                    new_version="${OPTARG#*=}"
                    ;;
                dry-run)
                    dry_run=true
                    ;;
                *)
                    echo "Invalid option: --${OPTARG}" >&2
                    echo "Usage: $0 [-b branch] [-v version] [--build build-number] [-d]" >&2
                    exit 1
                    ;;
            esac
            ;;
        b)
            branch="$OPTARG"
            ;;
        v)
            new_version="$OPTARG"
            ;;
        d)
            dry_run=true
            ;;
        *)
            echo "Usage: $0 [-b branch] [-v version] [--build] [-d]" >&2
            exit 1
            ;;
    esac
done

# Get the initial version and build number
getVersion "$project" "$target"

# Get the build number if one to set is not provided
if [ -z "$build_number" ]; then
    getOldBuild "$project"
fi

# Update version if provided
if [ ! -z "$new_version" ]; then
    echo "Updating version to: $new_version"
    updateVersion "$new_version" "$project"
    # Get the updated version
    getVersion "$project" "$target"
fi

# Update build number
if [ "$build_number_provided" = true ]; then
    increment_build_number $build_number "$project"
else
    increment_build_number $(($build_number + 1)) "$project"
fi
getBuild "$project"

# Commit the change
if [ "$dry_run" = true ]; then
    echo "[DRY RUN] Would commit build number change"
    echo "[DRY RUN] Would perform git operations"
else
    echo "Committing the build number change"
    git commit -a -m "Bumped Build Number"
    latest_git_commit=$(git rev-parse HEAD)
    
    # Tag the commit
    git tag -a "v$version($build_number)" -m ""
    git push
    git push --tags

    # Commit and push the build number change
    commit_message="$version($build_number)"
    commit_description="This is the beta release for $version($build_number)"

    # Get the original branch
    original_branch=$(git rev-parse --abbrev-ref HEAD)

    # Switch to the target branch (using the value from --branch or -b flag)
    git switch $branch
    git pull

    # Merge changes from the main branch
    git merge --squash -X theirs $original_branch
    git commit -a -m "$commit_message" -m "$commit_description"

    # Push the changes
    git push

    # Switch back to the original branch
    git checkout "$original_branch"
fi

echo ""
echo "Beta push complete!"
