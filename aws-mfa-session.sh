#!/usr/bin/env sh

################################################################################
# Define variables
################################################################################
script_is_sourced=0

if [ -n "$BASH_VERSION" ]; then
    (return 0 2>/dev/null) && script_is_sourced=1
elif [ -n "$ZSH_EVAL_CONTEXT" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) script_is_sourced=1;; esac
else
    case ${0##*/} in dash|sh) script_is_sourced=1;; esac
fi

aws_role_name="${AWS_ROLE_NAME:-}"
aws_profile_name="${AWS_PROFILE_NAME:-'default'}"
aws_role_arn="${AWS_ROLE_ARN:-}"
aws_mfa_session_duration="${AWS_MFA_SESSION_DURATION:-86400}"
aws_session_path="${HOME}"/.aws

aws_session_epoch_expiry_date=''
aws_mfa_session_credentials=''
aws_role_session_credentials=''

profile_not_found="Profile name not found."
role_not_found="Role ARN or name not found."
something_went_wrong="    Something went wrong. Please check your credentials and try again."

################################################################################
# Handle arguments
################################################################################
for arg in "$@"; do
    # Assume a role
    # [ -a | --assume-role ]
    if [ -z "${AWS_ROLE_NAME}" ]; then
        if [ -n "${aws_role_name_flag}" ]; then
            aws_role_name_flag=''
            aws_role_name="${arg}"
        fi

        if [ "${arg}" = "-a" ] || [ "${arg}" = "--assume-role" ]; then
            aws_role_name_flag=true
        fi
    fi

    # For running AWS CLI commands inside of this script
    # [ -c | --cli ]
    if [ -n "${aws_run_cli_flag}" ]; then
        aws_run_cli_flag=''
        aws_run_cli="${arg}"
    fi

    if [ "${arg}" = "-c" ] || [ "${arg}" = "--cli" ]; then
        aws_run_cli_flag=true
    fi

    # Set the MFA session duration
    # [ -d | --duration ]
    if [ -z "${AWS_MFA_SESSION_DURATION}" ]; then
        if [ -n "${aws_mfa_session_duration_flag}" ]; then
            aws_mfa_session_duration_flag=''
            aws_mfa_session_duration="${arg}"
        fi

        if [ "${arg}" = "-d" ] || [ "${arg}" = "--duration" ]; then
            aws_mfa_session_duration_flag=true
        fi
    fi

    # Specify a profile name
    # [ -p | --profile ]
    # shellcheck disable=SC2153
    if [ -z "${AWS_PROFILE_NAME}" ]; then
        if [ -n "${aws_profile_name_flag}" ]; then
            aws_profile_name_flag=''
            aws_profile_name="${arg}"
        fi

        if [ "${arg}" = "-p" ] || [ "${arg}" = "--profile" ]; then
            aws_profile_name_flag=true
        fi
    fi

    # The role ARN that will be used as the '--serial-number'
    # [ -r | --role-arn ]
    # shellcheck disable=SC2153
    if [ -z "${AWS_ROLE_ARN}" ]; then
        if [ -n "${aws_role_arn_flag}" ]; then
            aws_role_arn_flag=''
            aws_role_arn="${arg}"
        fi

        if [ "${arg}" = "-r" ] || [ "${arg}" = "--role-arn" ]; then
            aws_role_arn_flag=true
        fi
    fi

    # The token code that is generated for MFA purposes
    # [ -t | --token-code ]
    if [ -n "${aws_token_code_flag}" ]; then
        aws_token_code_flag=''
        aws_token_code="${arg}"
    fi

    if [ "${arg}" = "-t" ] || [ "${arg}" = "--token-code" ]; then
        aws_token_code_flag=true
    fi
done

################################################################################
# Define internal functions
################################################################################
configure_aws_credentials(){
    if [ -n "${1}" ]; then
        # Set the credentials
        AWS_ACCESS_KEY_ID="$(echo "${1}" | awk '{ print $2 }')"
        AWS_SECRET_ACCESS_KEY="$(echo "${1}" | awk '{ print $4 }')"
        AWS_SESSION_TOKEN="$(echo "${1}" | awk '{ print $5 }')"

        # Cache the credentials
        # If '$aws_role_name' isn't set, this function
        # won't write to the '~/.aws/credentials' file
        if [ -n "${2}" ]; then
            aws --profile "${2}" configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
            aws --profile "${2}" configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
            aws --profile "${2}" configure set aws_session_token "${AWS_SESSION_TOKEN}"
        fi
    elif [ -n "${2}" ]; then
        # Attempt to fetch cached credentials
        AWS_ACCESS_KEY_ID=$(aws --profile "${2}" configure get aws_access_key_id)
        AWS_SECRET_ACCESS_KEY=$(aws --profile "${2}" configure get aws_secret_access_key)
        AWS_SESSION_TOKEN=$(aws --profile "${2}" configure get aws_session_token)
    else
        printf '%s\n' "${something_went_wrong}"
        exit 127
    fi

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
}

generate_aws_mfa_session_credentials(){
    if [ -z "${aws_profile_name}" ]; then
        printf '%s\n' "${profile_not_found}"
        exit 127
    fi

    request_token_code

    aws_mfa_arn=$(aws --profile "${aws_profile_name}" sts get-caller-identity --output text --query 'Arn' | sed 's|:user|:mfa|g')
    aws_session_epoch_expiry_date=$(( $(date +%s) + aws_mfa_session_duration ))

    printf '%s\n' "    Acquiring the MFA session credentials: \"aws sts get-session-token --duration ${aws_mfa_session_duration} --serial-number ${aws_mfa_arn} --token-code ${aws_token_code}\"";

    aws_mfa_session_credentials=$(\
        aws \
        --profile "${aws_profile_name}" \
        sts get-session-token \
        --duration "${aws_mfa_session_duration}" \
        --serial-number "${aws_mfa_arn}" \
        --token-code "${aws_token_code}" \
        --output text \
    )

    aws_mfa_session_credentials_exit_code="${?}"

    if [ "${aws_mfa_session_credentials_exit_code}" = '0' ]; then
        configure_aws_credentials "${aws_mfa_session_credentials}" "${aws_profile_name}-mfa-session"
        aws --profile "${aws_profile_name}-mfa-session" configure set session_expiry_date "$aws_session_epoch_expiry_date"
        aws_mfa_session_duration_hours=$((aws_mfa_session_duration/3600))
        printf '%s\n' "    The '${aws_profile_name}-mfa-session' credentials have been set and will be valid for ${aws_mfa_session_duration_hours} hour(s)."
    else
        printf '%s\n' "${something_went_wrong}"
        exit "${aws_mfa_session_credentials_exit_code}"
    fi
}

generate_aws_role_session_credentials(){
    if [ -z "${aws_profile_name}" ]; then
        printf '%s\n' "${profile_not_found}"
        exit 127
    fi

    if [ -n "${aws_role_name}" ]; then
        aws_role_arn_or_name="${aws_role_name}"

        if [ -z "${AWS_ROLE_ARN}" ] && [ -z "${aws_role_arn}" ]; then
            aws_role_arn=$(aws --profile "${aws_role_name}" configure get role_arn)
        fi

        aws --profile "${aws_role_name}" configure set source_profile "${aws_profile_name}-mfa-session"
    elif [ -n "${aws_role_arn}" ]; then
        aws_role_arn_or_name="${aws_role_arn}"
    else
        printf '%s\n' "${role_not_found}"
        exit 127
    fi

    printf '\n%s\n' "    Acquiring the 'assume-role' session credentials: \"aws --profile ${aws_profile_name} sts assume-role --role-arn ${aws_role_arn} --role-session-name aws_mfa_session_${aws_session_epoch_expiry_date}\"";

    aws_role_session_credentials=$(\
        aws \
        --profile "${aws_profile_name}" \
        sts assume-role \
        --role-arn "${aws_role_arn}" \
        --role-session-name "aws_mfa_session_${aws_session_epoch_expiry_date}" \
        --output text | \
        grep "^CREDENTIALS"\
    )

    aws_role_session_credentials_exit_code="${?}"

    if [ "${aws_role_session_credentials_exit_code}" = '0' ]; then
        configure_aws_credentials "${aws_role_session_credentials}" "${aws_role_name}"
        printf '%s\n' "    The '${aws_role_arn_or_name}' role credentials have been set."
    else
        printf '%s\n' "${something_went_wrong}"
        exit "${aws_role_session_credentials_exit_code}"
    fi
}

get_aws_mfa_credentials(){
    if [ -z "${aws_profile_name}" ]; then
        printf '%s\n' "${profile_not_found}"
        exit 127
    fi

    aws_session_epoch_expiry_date=$(aws configure get session_expiry_date --profile "${aws_profile_name}-mfa-session")

    # shellcheck disable=SC2181
    if [ "${?}" -gt '0' ] || [ "$(date +%s)" -ge "${aws_session_epoch_expiry_date:-'0'}" ]; then
        generate_aws_mfa_session_credentials
    else
        printf '%s\n' "> Looking for valid MFA session credentials...";
        printf '%s\n' "    Active credentials were found for the '${aws_profile_name}-mfa-session' profile";
    fi
}

request_token_code(){
    if [ -z "${aws_token_code}" ]; then
        # Ask for the AWS MFA code
        stty -echo
        printf "> Please enter your AWS MFA security code: "
        # shellcheck disable=SC2162
        read aws_token_code
        stty echo
        printf "\n"
    else
        if printf '%s' "${aws_token_code}" | grep -Eq '^[0-9]{6}$'; then
            # The AWS MFA security code has been supplied as an argument
            printf '%s\n' "> AWS MFA security code passed as argument..."
        else
            printf '%s\n' "> Invalid AWS MFA security code. Exiting..."
            exit 127
        fi
    fi
}

################################################################################
# Ensure the local AWS directory existss
################################################################################
if [ -d "${aws_session_path}" ]; then
    mkdir -p "${aws_session_path}"
fi

################################################################################
# Generate credentials and/or run 'aws' commands within this script
# Put credentials in '~/.aws/<config|credentials>'
################################################################################
if [ -n "${aws_profile_name}" ] && [ "${script_is_sourced}" = '0' ]; then
    # Create an AWS MFA session
    if [ -z "${aws_role_name}" ]; then
        get_aws_mfa_credentials

    # Create an AWS MFA session AND create an 'assume-role' session
    else
        get_aws_mfa_credentials
        generate_aws_role_session_credentials

        # Run 'aws' commands
        if [ -n "${aws_run_cli}" ]; then
            aws_run_cli_test_str=$(echo "${aws_run_cli}" | sed "s/^\(aws\).*/\1/")

            if test "${aws_run_cli_test_str}" = 'aws'; then
                eval "${aws_run_cli}"
            else
                printf '%s\n' "> Invalid AWS CLI command. Exiting..."
                exit 127
            fi
        fi
    fi
################################################################################
# Export AWS credentials as environment variables when this script is sourced
################################################################################
elif [ -n "${aws_profile_name}" ] && [ "${script_is_sourced}" = '1' ]; then
    if [ -n "${aws_role_arn}" ] || [ -n "${aws_role_name}" ]; then
        get_aws_mfa_credentials
        generate_aws_role_session_credentials

        configure_aws_credentials "${aws_role_session_credentials}" "${aws_role_name}"

        printf '%s\n' "> The AWS environment variables were sucessfully exported."
    else
        printf '%s\n' "${role_not_found}"
        exit 127
    fi
else
    printf '%s\n' "${profile_not_found}"
    exit 127
fi
