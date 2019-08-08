# aws-mfa-session

[![Build Status](https://travis-ci.org/CoursePark/aws-mfa-session.svg?branch=master)](https://travis-ci.org/CoursePark/aws-mfa-session)
[![NPM version](https://badge.fury.io/js/aws-mfa-session.svg)](http://badge.fury.io/js/aws-mfa-session)
[![GitHub version](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session.svg)](https://badge.fury.io/gh/CoursePark%2Faws-mfa-session)

Generate MFA session credentials for `aws-cli`.

## Install

    npm i aws-mfa-session

## Usage

The script can be configured with arguments and/or environment variables.

### Environment variables

- AWS credentials set via environment variables take precedence over the values found in `/home/<USER>/.aws/credentials`.
- The values assigned to `aws-mfa-session` environment variables take precedence over the values passed with flags.
  - The `aws-mfa-session` script can be configured via the following environment variables.

        $AWS_MFA_SESSION_DURATION
        $AWS_PROFILE_NAME
        $AWS_ROLE_ARN
        $AWS_ROLE_NAME

### Argument flags

- `[ -a | --assume-role ]`: This flag is for passing a role name
- `[ -c | --cli ]`: This flag is for passing 'aws' commands
- `[ -d | --duration ]`: This flag is for passing the MFA session duration (DEFAULT: 86400)
- `[ -p | --profile ]`: This flag is for passing a profile name (DEFAULT: 'default')
- `[ -r | --role-arn ]`: This flag is for passing the role ARN
- `[ -t | --token-code ]`: This flag is for passing an MFA token code

#### Notes

- If only `--profile` is passed as an argument, only the MFA session credentials will be generated.
- If only `--profile` and `--assume-role` are passed as arguments, both MFA and role session credentials will be generated.

### Examples

#### Configure the script via argument flags and generate MFA session credentials.

      $ /path/to/aws-mfa-session.sh -p <AWS_PROFILE_NAME>
      $ aws --profile <AWS_PROFILE_NAME>-mfa-session sts assume-role --role-arn <AWS_ROLE_ARN> --role-session-name <AWS_ROLE_SESSION_NAME>"

#### Configure the script via argument flags and generate MFA + role session credentials.

      $ /path/to/aws-mfa-session.sh -p <AWS_PROFILE_NAME> -a <AWS_ROLE_NAME>
      $ aws --profile <AWS_ROLE_NAME> s3 ls <S3_BUCKET_URL>

#### Configure the script via argument flags and environment variables then run an 'aws' command as a child process.

      $ AWS_ROLE_NAME=<AWS_ROLE_NAME>
      $ /path/to/aws-mfa-session.sh -p <AWS_PROFILE_NAME> -c 'aws s3 ls <S3_BUCKET_URL>'

#### Configure the script via environment variables and source it.

- A) Set `$AWS_PROFILE_NAME` and `$AWS_ROLE_NAME` then source the script.

      #!/usr/bin/env sh

      # Will fallback to 'default' if not set
      AWS_PROFILE_NAME='<AWS_PROFILE_NAME>'
      export AWS_PROFILE_NAME

      AWS_ROLE_NAME='<AWS_ROLE_NAME>'
      export AWS_ROLE_NAME

      # Generate the session credentials
      . /path/to/aws-mfa-session.sh

      # 'aws-cli' commands go here...

- B) Set the AWS credentials and `$AWS_ROLE_ARN` then source the script.

      #!/usr/bin/env sh

      AWS_ROLE_ARN=<AWS_ROLE_ARN>
      export AWS_ROLE_ARN

      # Alternatively, if '$AWS_PROFILE_NAME' is set the
      # access id and secret key do not need to be set here
      AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
      export AWS_ACCESS_KEY_ID

      AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
      export AWS_SECRET_ACCESS_KEY

      # Generate the session credentials
      . /path/to/aws-mfa-session.sh

      # 'aws-cli' commands go here...

### Configuration files

A very simple configuration should look something like this before running the `aws-mfa-session` script:

- `/home/<USER>/.aws/credentials`

      [default]
      aws_access_key_id = AKIAIOSFODNN7EXAMPLE
      aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

      [<profile_name>]
      aws_access_key_id = AKIAIOSHSWBG7EXAMPLE
      aws_secret_access_key = wJalrXUtnRYBQ/K7MTONJ/bPxRfiCYEXAMPLEKEY

- `/home/<USER>/.aws/config`

      [default]
      region = ca-central-1

      [profile <role_name>]
      region = ca-central-1
      role_arn = arn:aws:iam::xxxxxxxxxxxx:role/<ROLE_NAME>

Once the `aws-mfa-session` script has run the above configuration should now look somethig like this:

- `/home/<USER>/.aws/credentials`

      [default]
      aws_access_key_id = AKIAIOSFODNN7EXAMPLE
      aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

      [<profile_name>]
      aws_access_key_id = AKIAIOSHSWBG7EXAMPLE
      aws_secret_access_key = wJalrXUtnRYBQ/K7MTONJ/bPxRfiCYEXAMPLEKEY

      [<profile_name>-mfa-session]
      aws_access_key_id = AKIAUGDWQFHJ7EXAMPLE
      aws_secret_access_key = wJalrXUtnRYBQ/YRNHMKL/bPxRfiCYEXAMPLEKEY

      [<role_name]
      aws_access_key_id = AKIANEQJSRPC7EXAMPLE
      aws_secret_access_key = wJalrXUtnRYBQ/UAHTMPD/bPxRfiCYEXAMPLEKEY
      aws_session_token = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

- `/home/<USER>/.aws/config`

      [default]
      region = ca-central-1

      [profile <role_name>]
      region = ca-central-1
      role_arn = arn:aws:iam::xxxxxxxxxxxx:role/<ROLE_NAME>
      source_profile = <profile_name>-mfa-session

      [profile <profile_name>-mfa-session]
      session_expiry_date = 1501010101
