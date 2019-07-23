# aws-mfa-session

[![Build Status](https://travis-ci.org/CoursePark/aws-mfa-session.svg?branch=master)](https://travis-ci.org/CoursePark/aws-mfa-session)
[![NPM version](https://badge.fury.io/js/aws-mfa-session.svg)](http://badge.fury.io/js/aws-mfa-session)
[![GitHub version](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session.svg)](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session)

Generate MFA session credentials for `aws-cli`.

## Install

    npm i aws-mfa-session

## Usage

### Flags

- `/path/to/aws-mfa-session.sh -p <PROFILE_NAME> -r <ROLE_ARN> -c <CLI_CMD>`

      - `[ -c | --cli ]`: This flag is for passing 'aws' commands
      - `[ -p | --profile ]`: This flag is for passing a profile name
      - `[ -r | --role-arn ]`: This flag is for passing the role ARN
      - `[ -t | --token-code ]`: This flag is for passing an MFA token code

### Environment variables

- The values assigned to environment variables take precedence over the values passed with flags and the values found in `/home/<USER>/.aws/credentials`.
- The `aws-mfa-session` script can be configured via the following environment variables.

      $AWS_ACCESS_KEY_ID
      $AWS_PROFILE_NAME
      $AWS_ROLE_ARN
      $AWS_SECRET_ACCESS_KEY

### The `aws-mfa-session` script

#### A. Configure the script via environment variables.

- Source the script.

      #!/usr/bin/env sh

      AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
      export AWS_ACCESS_KEY_ID

      AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
      export AWS_SECRET_ACCESS_KEY
    
      AWS_ROLE_ARN=<AWS_ROLE_ARN>
      export AWS_ROLE_ARN

      # Profiles are optional
      AWS_PROFILE_NAME='<aws_profile_name>'
      export AWS_PROFILE_NAME

      # Generate the session credentials
      . /path/to/aws-mfa-session.sh

      # `aws-cli` commands go here...

- Call the script via the command line.

      $ AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID> && \
      AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY> && \
      AWS_ROLE_ARN=<AWS_ROLE_ARN>

      $ /path/to/aws-mfa-session.sh ...

#### B. Use the credentials and config found in `/home/<USER>/.aws`.

- `/home/<USER>/.aws/credentials`

      [default]
      aws_access_key_id = AKIAIOSFODNN7EXAMPLE
      aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

      [<credentials_profile_name>]
      aws_access_key_id = AKIAIOSHSWBG7EXAMPLE
      aws_secret_access_key = wJalrXUtnRYBQ/K7MTONJ/bPxRfiCYEXAMPLEKEY

- `/home/<USER>/.aws/config`

      [default]
      output = json
      region = ca-central-1

      [profile <source_profile_name>]
      region = ca-central-1

      [profile <credentials_profile_name>]
      role_arn = arn:aws:iam::xxxxxxxxxxxx:role/<ROLE_NAME>
      source_profile = <source_profile_name>

- Pass the `profile` flag to the script.

      $ /path/to/aws-mfa-session.sh \
        -p <profile_name> \
        -c 'aws ...'

### Notes

- The session credentials will be stored in `/home/<USER>/.aws/session-credentials`.
- The MFA security code can also be passed as an argument to `aws-mfa-session.sh`.
