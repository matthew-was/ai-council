#!/bin/bash

# Semantic Versioning Manager for AI Council Skills
# Implements SemVer 2.0.0 specification

set -e

# SemVer regex pattern (simplified for bash)
SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"

# Function to validate SemVer format
validate_semver() {
    local version="$1"
    if [[ "$version" =~ $SEMVER_REGEX ]]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# Function to compare two SemVer versions
# Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Validate both versions
    if [[ $(validate_semver "$v1") == "false" || $(validate_semver "$v2") == "false" ]]; then
        echo "Invalid version format" >&2
        return 1
    fi

    # Split versions into components
    IFS='.' read -r v1_major v1_minor v1_patch <<< "${v1%-*}"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "${v2%-*}"

    # Compare major versions
    if [[ $v1_major -lt $v2_major ]]; then echo "-1"; return 0; fi
    if [[ $v1_major -gt $v2_major ]]; then echo "1"; return 0; fi

    # Compare minor versions
    if [[ $v1_minor -lt $v2_minor ]]; then echo "-1"; return 0; fi
    if [[ $v1_minor -gt $v2_minor ]]; then echo "1"; return 0; fi

    # Compare patch versions
    if [[ $v1_patch -lt $v2_patch ]]; then echo "-1"; return 0; fi
    if [[ $v1_patch -gt $v2_patch ]]; then echo "1"; return 0; fi

    echo "0"
    return 0
}

# Function to check version constraint satisfaction
check_constraint() {
    local version="$1"
    local constraint="$2"

    # Validate version format
    if [[ $(validate_semver "$version") == "false" ]]; then
        echo "Invalid version format: $version" >&2
        return 1
    fi

    # Handle different constraint types
    case "$constraint" in
        ^*)
            # Caret constraint: ^1.2.3 := >=1.2.3 <2.0.0
            base_version="${constraint:1}"
            compare_result=$(compare_versions "$version" "$base_version")
            if [[ "$compare_result" -lt 0 ]]; then
                echo "false"
                return 0
            fi

            # Get next major version
            IFS='.' read -r major minor patch <<< "${base_version%-*}"
            next_major=$((major + 1))
            next_version="${next_major}.0.0"

            compare_result=$(compare_versions "$version" "$next_version")
            if [[ "$compare_result" -ge 0 ]]; then
                echo "false"
                return 0
            fi

            echo "true"
            ;;
        ~*)
            # Tilde constraint: ~1.2.3 := >=1.2.3 <1.3.0
            base_version="${constraint:1}"
            compare_result=$(compare_versions "$version" "$base_version")
            if [[ "$compare_result" -lt 0 ]]; then
                echo "false"
                return 0
            fi

            # Get next minor version
            IFS='.' read -r major minor patch <<< "${base_version%-*}"
            next_minor=$((minor + 1))
            next_version="${major}.${next_minor}.0"

            compare_result=$(compare_versions "$version" "$next_version")
            if [[ "$compare_result" -ge 0 ]]; then
                echo "false"
                return 0
            fi

            echo "true"
            ;;
        ">="*)
            # Greater than or equal
            required_version="${constraint:2}"
            compare_result=$(compare_versions "$version" "$required_version")
            if [[ "$compare_result" -ge 0 ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        ">"*)
            # Greater than
            required_version="${constraint:1}"
            compare_result=$(compare_versions "$version" "$required_version")
            if [[ "$compare_result" -gt 0 ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        "<="*)
            # Less than or equal
            required_version="${constraint:2}"
            compare_result=$(compare_versions "$version" "$required_version")
            if [[ "$compare_result" -le 0 ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        "<"*)
            # Less than
            required_version="${constraint:1}"
            compare_result=$(compare_versions "$version" "$required_version")
            if [[ "$compare_result" -lt 0 ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        "="*)
            # Equal
            required_version="${constraint:1}"
            compare_result=$(compare_versions "$version" "$required_version")
            if [[ "$compare_result" -eq 0 ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        *)
            # Exact match
            if [[ "$version" == "$constraint" ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
    esac
}

# Function to bump version
bump_version() {
    local current_version="$1"
    local bump_type="$2"  # major, minor, or patch

    # Validate current version
    if [[ $(validate_semver "$current_version") == "false" ]]; then
        echo "Invalid version format: $current_version" >&2
        return 1
    fi

    # Split version components
    IFS='.' read -r major minor patch <<< "${current_version%-*}"

    # Bump the appropriate component
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Invalid bump type: $bump_type. Use major, minor, or patch." >&2
            return 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Function to validate all skill versions in registry
validate_registry_versions() {
    local registry_file="${1:-.vibe/skills/skills.json}"

    if [[ ! -f "$registry_file" ]]; then
        echo "Registry file not found: $registry_file" >&2
        return 1
    fi

    # Use jq to extract and validate versions
    if command -v jq &> /dev/null; then
        local all_valid=true
        jq -r '.skills[]?.metadata.version' "$registry_file" | while read version; do
            if [[ $(validate_semver "$version") == "false" ]]; then
                echo "❌ Invalid version: $version"
                all_valid=false
            else
                echo "✅ Valid version: $version"
            fi
        done

        if [[ "$all_valid" == "true" ]]; then
            return 0
        else
            return 1
        fi
    else
        echo "jq not available for comprehensive validation" >&2
        return 1
    fi
}

# Function to check version compatibility across skills
check_compatibility() {
    local skill1="$1"
    local version1="$2"
    local skill2="$3"
    local version2="$4"
    local constraint="$5"

    echo "Checking compatibility: $skill1@$version1 with $skill2@$version2 (constraint: $constraint)"

    # Validate versions
    if [[ $(validate_semver "$version1") == "false" || $(validate_semver "$version2") == "false" ]]; then
        echo "❌ Invalid version format"
        return 1
    fi

    # Check constraint
    if [[ -n "$constraint" ]]; then
        if [[ $(check_constraint "$version2" "$constraint") == "true" ]]; then
            echo "✅ Compatible: $version2 satisfies $constraint"
            return 0
        else
            echo "❌ Incompatible: $version2 does not satisfy $constraint"
            return 1
        fi
    else
        echo "⚠️  No constraint specified, assuming compatible"
        return 0
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        validate)
            validate_semver "$@"
            ;;
        compare)
            compare_versions "$@"
            ;;
        constraint|check)
            check_constraint "$@"
            ;;
        bump)
            bump_version "$@"
            ;;
        validate-registry)
            validate_registry_versions "$@"
            ;;
        compatibility|compat)
            check_compatibility "$@"
            ;;
        *)
            echo "AI Council Semantic Versioning Manager"
            echo "====================================="
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  validate <version>          - Validate SemVer format"
            echo "  compare <v1> <v2>           - Compare two versions (-1, 0, 1)"
            echo "  constraint <version> <constraint> - Check constraint satisfaction"
            echo "  bump <version> <type>       - Bump version (major/minor/patch)"
            echo "  validate-registry [file]    - Validate all versions in registry"
            echo "  compatibility <s1> <v1> <s2> <v2> [constraint] - Check compatibility"
            echo ""
            echo "Examples:"
            echo "  $0 validate 1.2.3"
            echo "  $0 compare 1.2.3 1.2.4"
            echo "  $0 constraint 1.2.5 ^1.2.3"
            echo "  $0 bump 1.2.3 patch"
            echo "  $0 validate-registry"
            echo "  $0 compatibility doc_skill 1.2.3 code_skill 1.1.0 ^1.0.0"
            ;;
    esac
}

# Run main function
main "$@"
