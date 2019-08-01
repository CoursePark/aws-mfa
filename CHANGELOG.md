# Changelog
All notable changes to this project will be documented in this file.

---

## [2.0.1](https://github.com/CoursePark/aws-mfa-session/releases/tag/2.0.1) - 2019-08-01
## Changed
- Refactor to make use of the 'export_aws_credentials' function

### Fixed
- Use command substitution to properly parse '$aws_session_expiry_date' (macOS)

---

## [2.0.0](https://github.com/CoursePark/aws-mfa-session/releases/tag/2.0.0) - 2019-07-24
### Added
- Add the 'cli' flag for passing 'aws' commands
- Add the 'profile' flag for passing a profile name
- Add the 'role-arn' flag for passing the role ARN
- Add the 'token-code' flag for passing an MFA token code
- Fallback to credentials found in '/home/<USER>/.aws'

### Changed
- Environment variable names
- Update the 'usage' section of `README` file

### Fixed
- Remove the '-r' flag from 'sed' command (macOS: illegal option)
- Fail if the exit code for the `assume-role` command is not equal to `0`

---

## [1.0.0](https://github.com/CoursePark/aws-mfa-session/releases/tag/1.0.0) - 2019-07-19
### Added
- Documentation
- Support for AWS IAM roles

---

## [0.1.4](https://github.com/CoursePark/aws-mfa-session/releases/tag/0.1.4) - 2019-07-18
### Fixed
- Properly handle the expiry date

---

## [0.1.3](https://github.com/CoursePark/aws-mfa-session/releases/tag/0.1.3) - 2019-07-17
### Changed
- Use the correct letter case for variables

### Fixed
- Exit the script when AWS session credentials are empty
- Properly handle success and fail messages
- Replace `/tmp` with `/home/<user>` for safer credential storage
- Use the correct `date` command for macOS

---

## [0.1.2](https://github.com/CoursePark/aws-mfa-session/releases/tag/v0.1.2) - 2019-07-12
### Added
- Documentation

### Fixed
- Ensure that the `/tmp/.aws` directory exists
- Corrected typos

---

## [0.1.1](https://github.com/CoursePark/aws-mfa-session/releases/tag/v0.1.1) - 2019-07-12
### Fixed
- Ensure that the `/tmp/.aws/session-credentials` file exists

---

## [0.1.0](https://github.com/CoursePark/aws-mfa-session/releases/tag/v0.1.0) - 2019-07-12
### Added
- Documentaion
- Scripts
- Settings

---

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
