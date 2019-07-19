#!/usr/bin/env sh

################################################################
# Define AWS variables
################################################################

# Imported
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-}

# Local
aws_iam_user_device_arn=$(aws sts get-caller-identity --output text --query 'Arn' | sed -r 's|:user|:mfa|g')

aws_session_path="${HOME}"/.aws
mkdir -p "${aws_session_path}"

aws_iam_role_session_credentials=$(\
    touch "${aws_session_path}"/session-credentials;\
    cat "${aws_session_path}"/session-credentials\
)

aws_session_duration=86400
aws_session_expiry_date="$(echo "${aws_iam_role_session_credentials}" | awk '{ print $3 }')"

################################################################
# Fetch and cache AWS session credentials
################################################################
if [ -n "${aws_session_expiry_date}" ]; then
    platform=$(uname -s)

    if [ -z "${platform##*'Darwin'*}" ]; then
        # 'date' will fail on macOS if the timestamp contains a '[A-z]'
        # In this case, the '[A-z]' characters are removed with '%?' and 'sed'
        aws_session_epoch_expiry_date=$(date -j -f "%Y-%m-%d %H:%M" "${aws_session_expiry_date%?}" +%s | sed 's|T| |g')
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
    if [ -z "${1}" ]; then
        # Ask for the AWS MFA code
        stty -echo
        printf "> Please enter your AWS MFA security code: "
        # shellcheck disable=SC2162
        read aws_mfa_security_code
        stty echo
        printf "\n"
    else
        if printf '%s' "${1}" | grep -Eq '^[0-9]{6}$'; then
            # The AWS MFA security code has been supplied as an argument
            printf '%s\n' "> AWS MFA security code discovered..."
            aws_mfa_security_code="${1}"
        fi
    fi

    if [ -z "${aws_mfa_security_code}" ]; then
        printf '%s\n' "> AWS MFA security code not found. Exiting..."
        exit 127
    fi

    # Use the provided credentials to generate session credentials
    printf '%s\n' "    Acquiring AWS session credentials: \"aws sts get-session-token --serial-number ${aws_iam_user_device_arn} --token-code ${aws_mfa_security_code}\"";
    aws_iam_user_session_credentials=$(\
        aws sts get-session-token \
        --duration "${aws_session_duration}" \
        --serial-number "${aws_iam_user_device_arn}" \
        --token-code "${aws_mfa_security_code}" \
        --output text \
    )

    # Set the AWS MFA credential variables
    AWS_ACCESS_KEY_ID="$(echo "${aws_iam_user_session_credentials}" | awk '{ print $2 }')"
    AWS_SECRET_ACCESS_KEY="$(echo "${aws_iam_user_session_credentials}" | awk '{ print $4 }')"
    AWS_SESSION_TOKEN="$(echo "${aws_iam_user_session_credentials}" | awk '{ print $5 }')"

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN

    session_id=$(date +%s)

    # Generate role session credentials
    aws_iam_role_session_credentials=$(\
        aws sts assume-role \
        --role-arn "${AWS_IAM_ROLE_DEVICE_ARN}" \
        --role-session-name "aws_mfa_session_${session_id}" \
        --output text | \
        grep "^CREDENTIALS"\
    )

    printf '%s\n' "${aws_iam_role_session_credentials}" | tee "${aws_session_path}"/session-credentials >/dev/null 2>&1
    
    if [ -s "${aws_session_path}"/session-credentials ]; then
        printf '%s\n' "    The AWS session credentials have been updated and will be valid for 24 hours."
    else
        printf '%s\n' "    Something went wrong. Please check your credentials and try again."
        exit 1
    fi
fi

# Set the AWS role credential variables
AWS_ACCESS_KEY_ID="$(echo "${aws_iam_role_session_credentials}" | awk '{ print $2 }')"
AWS_SECRET_ACCESS_KEY="$(echo "${aws_iam_role_session_credentials}" | awk '{ print $4 }')"
AWS_SESSION_TOKEN="$(echo "${aws_iam_role_session_credentials}" | awk '{ print $5 }')"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
