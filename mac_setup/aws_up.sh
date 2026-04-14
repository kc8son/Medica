aws-up() {
  local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
  local requested_profile="${1:-}"
  local -a profiles
  local profile_count
  local selected
  local profile
  local sso_session start_url role_arn

  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is not installed or not in PATH."
    return 1
  fi

  if [ ! -f "$config_file" ]; then
    echo "AWS config file not found: $config_file"
    return 1
  fi

  mapfile -t profiles < <(aws configure list-profiles 2>/dev/null | awk 'NF')

  if [ "${#profiles[@]}" -eq 0 ]; then
    mapfile -t profiles < <(
      awk '
        /^\[profile / {
          gsub(/^\[profile /, "", $0)
          gsub(/\]$/, "", $0)
          print $0
        }
        /^\[default\]$/ { print "default" }
      ' "$config_file" | awk '!seen[$0]++'
    )
  fi

  if [ "${#profiles[@]}" -eq 0 ]; then
    echo "No AWS profiles found in $config_file"
    return 1
  fi

  if [ "${#profiles[@]}" -gt 1 ]; then
    mapfile -t profiles < <(printf '%s\n' "${profiles[@]}" | awk '$0 != "default"')
  fi

  if [ -n "$requested_profile" ]; then
    if printf '%s\n' "${profiles[@]}" | grep -Fxq "$requested_profile"; then
      profile="$requested_profile"
    else
      echo "Profile not found: $requested_profile"
      return 1
    fi
  else
    profile_count="${#profiles[@]}"

    if [ "$profile_count" -eq 1 ]; then
      profile="${profiles[0]}"
      echo "Using AWS profile: $profile"
    else
      echo "Available AWS profiles:"
      local i=1
      for profile in "${profiles[@]}"; do
        echo "  $i) $profile"
        i=$((i + 1))
      done

      printf "Select profile [1-%d]: " "$profile_count"
      read -r selected

      if ! [[ "$selected" =~ ^[0-9]+$ ]] || [ "$selected" -lt 1 ] || [ "$selected" -gt "$profile_count" ]; then
        echo "Invalid selection."
        return 1
      fi

      profile="${profiles[$((selected - 1))]}"
    fi
  fi

  export AWS_PROFILE="$profile"
  echo "AWS_PROFILE set to: $AWS_PROFILE"

  sso_session="$(aws configure get sso_session --profile "$profile" 2>/dev/null)"
  start_url="$(aws configure get sso_start_url --profile "$profile" 2>/dev/null)"
  role_arn="$(aws configure get role_arn --profile "$profile" 2>/dev/null)"

  if [ -n "$sso_session" ] || [ -n "$start_url" ]; then
    echo "Detected SSO profile. Logging in..."
    aws sso login --profile "$profile" || return 1
  elif [ -n "$role_arn" ]; then
    echo "Profile uses role assumption."
    echo "No explicit login step required. Credentials will be resolved when used."
  else
    echo "Profile appears to use static or other credentials."
    echo "No login step required."
  fi

  echo
  echo "Current caller identity:"
  aws sts get-caller-identity --profile "$profile" 2>/dev/null || \
    echo "Unable to retrieve caller identity yet. The profile may need credentials or an SSO login."
}