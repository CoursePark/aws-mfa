# aws-mfa-session

[![Build Status](https://travis-ci.org/CoursePark/aws-mfa-session.svg?branch=master)](https://travis-ci.org/CoursePark/aws-mfa-session)
[![NPM version](https://badge.fury.io/js/aws-mfa-session.svg)](http://badge.fury.io/js/aws-mfa-session)
[![GitHub version](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session.svg)](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session)

Generate MFA session credentials for `aws-cli`.

## Usage

The 1aws-mfa-session1 script requires that the AWS role credentials are set in the shell environment or in the `~/.aws/credentials` file.

    $AWS_ACCESS_KEY_ID
    $AWS_SECRET_ACCESS_KEY

The MFA device ARN identifier must be set in the shell environment.

    $AWS_MFA_DEVICE_ARN

Method A) Source the `aws-mfa-session.sh` file in your script before you make any AWS calls.

    #!/usr/bin/env sh

    . /path/to/aws-mfa-session.sh

    # `aws-cli` commands...

Method B) Set the AWS role credentials and call `/path/to/aws-mfa-session.sh` from the command line.

    $ AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID> && \
      AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY> && \
      AWS_MFA_DEVICE_ARN=<AWS_MFA_DEVICE_ARN> && \
      /path/to/aws-mfa-session.sh

### Notes

- The session credentials will be stored in `/tmp/.aws/session-credentials`.
- The MFA code can also be passed as an argument to `aws-mfa-session.sh`.
