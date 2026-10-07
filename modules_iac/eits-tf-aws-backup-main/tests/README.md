# UK&I Cloud Enablement Module Testing

See the confluence documentation [Module Testing](https://experian.atlassian.net/wiki/x/Mg4EF) for more details on how our modules are tested.

## Test Scenarios

- `tests/integration/`: full integration-style module test stack.
- `tests/malware_scan/`: dedicated scenario for validating malware scan variables (`backup_rules[*].scan_mode`, `scanner_resource_types`, and `scanner_role_arn`).
- `tests/lag_vault/`: Test LAG vault deployment and sharing
