# Changelog
All notable changes to this project will be documented in this file.

---

## [1.0.0](https://github.com/CoursePark/aws-mfa-session/releases/tag/v1.0.0) - 2019-07-19
### Added
- Documentation
- Support for AWS IAM roles

---

## [0.1.4](https://github.com/CoursePark/aws-mfa-session/releases/tag/v0.1.4) - 2019-07-18
### Fixed
- Properly handle the expiry date

---

## [0.1.3](https://github.com/CoursePark/aws-mfa-session/releases/tag/v0.1.3) - 2019-07-17
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
