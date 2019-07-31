#!/usr/bin/env sh

################################################################
# Define AWS variables
################################################################
for arg in "$@"; do
    # Run 'aws' commands
    # [ -c | --cli ]
    if [ -n "${aws_run_cli_flag}" ]; then
        aws_run_cli_flag=''
        aws_run_cli="${arg}"
    fi

    if [ "${arg}" = "-c" ] || [ "${arg}" = "--cli" ]; then
        aws_run_cli_flag=true
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

if [ -n "${AWS_PROFILE_NAME}" ]; then
    aws_profile_name="${AWS_PROFILE_NAME}"
fi

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    [ -n "${aws_profile_name}" ] && \
        AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile "${aws_profile_name}") || \
        AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id)

    export AWS_ACCESS_KEY_ID
fi

if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    [ -n "${aws_profile_name}" ] && \
        AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile "${aws_profile_name}") || \
        AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key)

    export AWS_SECRET_ACCESS_KEY
fi

if [ -z "${AWS_ROLE_ARN}" ] && [ -z "${aws_role_arn}" ]; then
    [ -n "${aws_profile_name}" ] && \
        aws_role_arn=$(aws configure get role_arn --profile "${aws_profile_name}") || \
        aws_role_arn=$(aws configure get default.role_arn)
elif [ -n "${AWS_ROLE_ARN}" ]; then
    aws_role_arn="${AWS_ROLE_ARN}"
fi

aws_user_arn=$(aws sts get-caller-identity --output text --query 'Arn' | sed 's|:user|:mfa|g')

aws_session_path="${HOME}"/.aws
mkdir -p "${aws_session_path}"

aws_role_session_credentials=$(\
    touch "${aws_session_path}"/session-credentials;\
    cat "${aws_session_path}"/session-credentials\
)

aws_session_duration=86400
aws_session_expiry_date="$(echo "${aws_role_session_credentials}" | awk '{ print $3 }')"

################################################################
# Fetch and cache AWS session credentials
################################################################
if [ -n "${aws_session_expiry_date}" ]; then
    platform=$(uname -s)

    if [ -z "${platform##*'Darwin'*}" ]; then
        # 'date' will fail on macOS if the timestamp contains '[A-z]' characters
        # In this case, the '[A-z]' characters are removed with '%?' and 'sed'
        aws_session_epoch_expiry_date=$(date -j -f "%Y-%m-%d %H:%M" "$(echo "${aws_session_expiry_date%?}" | sed 's|T| |g')" +%s)
    else
        aws_session_epoch_expiry_date=$(date -d "${aws_session_expiry_date}" +%s)
    fi
fi

if [ -n "${aws_session_expiry_date}" ] && [ "$(date +%s)" -lt "${aws_session_epoch_expiry_date}" ]; then
    printf '%s\n' "> Looking for AWS session credentials...";
    printf '%s\n' "    Using the credentials found in \"${aws_session_path}/session-credentials\"";
else
    printf '%s\n' ""

    # Require an AWS MFA code
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

    if [ -z "${aws_token_code}" ]; then
        printf '%s\n' "> AWS MFA security code not found. Exiting..."
        exit 127
    fi

    # Use the provided credentials to generate session credentials
    printf '%s\n' "    Acquiring AWS session credentials: \"aws sts get-session-token --duration ${aws_session_duration} --serial-number ${aws_user_arn} --token-code ${aws_token_code}\"";
    aws_user_session_credentials=$(\
        aws sts get-session-token \
        --duration "${aws_session_duration}" \
        --serial-number "${aws_user_arn}" \
        --token-code "${aws_token_code}" \
        --output text \
    )

    # Set the AWS MFA credential variables
    AWS_ACCESS_KEY_ID="$(echo "${aws_user_session_credentials}" | awk '{ print $2 }')"
    AWS_SECRET_ACCESS_KEY="$(echo "${aws_user_session_credentials}" | awk '{ print $4 }')"
    AWS_SESSION_TOKEN="$(echo "${aws_user_session_credentials}" | awk '{ print $5 }')"

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN

    session_id=$(date +%s)

    # Generate role session credentials
    aws_role_session_credentials=$(\
        aws sts assume-role \
        --role-arn "${aws_role_arn}" \
        --role-session-name "aws_mfa_session_${session_id}" \
        --output text | \
        grep "^CREDENTIALS"\
    )

    aws_assume_role_exit_code="${?}"

    printf '%s\n' "${aws_role_session_credentials}" | tee "${aws_session_path}"/session-credentials >/dev/null 2>&1
    
    if [ -s "${aws_session_path}"/session-credentials ] && [ "${aws_assume_role_exit_code}" = '0' ]; then
        printf '%s\n' "    The AWS session credentials have been updated and will be valid for 24 hours."
    else
        printf '%s\n' "    Something went wrong. Please check your credentials and try again."
        exit 1
    fi
fi

# Set the AWS role credential variables
AWS_ACCESS_KEY_ID="$(echo "${aws_role_session_credentials}" | awk '{ print $2 }')"
AWS_SECRET_ACCESS_KEY="$(echo "${aws_role_session_credentials}" | awk '{ print $4 }')"
AWS_SESSION_TOKEN="$(echo "${aws_role_session_credentials}" | awk '{ print $5 }')"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Run 'aws' commands
if [ -z "${aws_run_cli##*'aws'*}" ]; then
    eval "${aws_run_cli}"
fi
