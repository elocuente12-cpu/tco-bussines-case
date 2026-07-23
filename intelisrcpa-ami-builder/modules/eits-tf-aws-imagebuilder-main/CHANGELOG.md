# RELEASE NOTES

## v1.0.0 - July 2026

- Initial release
- OS-agnostic: supports Windows and Linux via `os_family` variable
- AWSTOE component management: build components (build/validate phases) and test components (test phase)
- External component ARN support (AWS managed components)
- Component parameters support
- Infrastructure configuration with IMDSv2 enforcement by default
- Image recipe with block device mappings, KMS encryption, SSM agent control
- Distribution configuration with multi-region and cross-account sharing
- Pipeline with dependency-aware scheduling (best practice)
- Amazon Inspector image scanning support
- SNS notifications support
- S3 logging for AWSTOE output
- Launch template association support
- Follows EITS module standard structure (naming, versioning, documentation)
