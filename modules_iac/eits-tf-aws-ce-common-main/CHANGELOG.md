# RELEASE NOTES

## 1.4.1 - 14th September 2026

- Updated confluence document links

## 1.4.0 - 3rd February 2026

- Added `module_version` output
- Updated `module_version` logic to fix static scan issue

## 1.3.0 - 10th September 2025

- Modified logic used to obtain the version to work with both artifactory and bitbucket module sources

## 1.2.0 - 20th June 2025

- Removed account naming check

## 1.1.0 - 31st March 2025

- Updated to hide tag checks if already tagged
- Updated to be usable from a non module base invocation

## 1.0.0 - 17th March 2025

- Cloned from original `eits-tf-aws-vars` module to help provide some version control when major breaking changes are added to the code.
- Updated tag checks to use the new Terraform native `check` function rather than the third party warning validations. This requires Terraform 1.5 or greater. 
