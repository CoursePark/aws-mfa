#!/usr/bin/env sh

################################################################
# Define AWS variables
################################################################

# Create the AWS session credentials directory
mkdir -p /tmp/.aws

AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_MFA_DEVICE_ARN=${AWS_MFA_DEVICE_ARN:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_SESSION_CREDENTIALS=$(touch /tmp/.aws/session-credentials; cat /tmp/.aws/session-credentials)
AWS_SESSION_DURATION=86400
AWS_SESSION_EXPIRY_DATE="$(echo "${AWS_SESSION_CREDENTIALS}" | awk '{ print $3 }')"
AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-}

################################################################
# Fetch and cache AWS session credentials
################################################################
if [ -n "${AWS_SESSION_EXPIRY_DATE}" ] && [ "$(date +%s)" -lt "$(date -d "${AWS_SESSION_EXPIRY_DATE}" +%s)" ]; then
    printf '%s\n' "> Looking for AWS session credentials...";
    printf '%s\n' "    Using the credentials found in \"/tmp/.aws/session-credentials\"";
else
    printf '%s\n' ""

    # Require an AWS MFA code
    if [ -z "${1}" ]; then
        # Ask for the AWS MFA code
        stty -echo
        printf "> Please enter your AWS MFA security code: "
        # shellcheck disable=SC2162
        read AWS_MFA_SECURITY_CODE
        stty echo
        printf "\n"
    else
        if printf '%s' "${1}" | grep -Eq '^[0-9]{6}$'; then
            # The AWS MFA security code has been supplied as an argument
            printf '%s\n' "> AWS MFA security code discovered..."
            AWS_MFA_SECURITY_CODE="${1}"
        fi
    fi

    if [ -z "${AWS_MFA_SECURITY_CODE}" ]; then
        printf '%s\n' "> AWS MFA security code not found. Exiting..."
        exit 127
    fi

    # Use the provided credentials to generate session credentials
    printf '%s\n' "    Acquiring AWS session credentials: \"aws sts get-session-token --serial-number ${AWS_MFA_DEVICE_ARN} --token-code ${AWS_MFA_SECURITY_CODE}\"";
    AWS_SESSION_CREDENTIALS=$(\
        aws sts get-session-token \
        --duration "${AWS_SESSION_DURATION}" \
        --serial-number "${AWS_MFA_DEVICE_ARN}" \
        --token-code "${AWS_MFA_SECURITY_CODE}"\
        --output text \
    )

    printf '%s\n' "${AWS_SESSION_CREDENTIALS}" | tee /tmp/.aws/session-credentials >/dev/null 2>&1
    printf '%s\n' "    The AWS session credentials have been updated and will be valid for 24 hours."
fi

# Set the AWS MFA credential variables
AWS_ACCESS_KEY_ID="$(echo "${AWS_SESSION_CREDENTIALS}" | awk '{ print $2 }')"
AWS_SECRET_ACCESS_KEY="$(echo "${AWS_SESSION_CREDENTIALS}" | awk '{ print $4 }')"
AWS_SESSION_TOKEN="$(echo "${AWS_SESSION_CREDENTIALS}" | awk '{ print $5 }')"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
