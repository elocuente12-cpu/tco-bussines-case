# EITS Cloud Enablement AWS S3 module

EITS Terraform module for AWS S3 bucket. This module will:

- Enable server-side encryption
- Enable bucket logging by default
- Enable bucket versioning by default
- Block public access by default
- Block insecure bucket access by default
- Create lifecycle policies, if required
- Enable intelligent tiering, if required
- Attach a bucket policy, if required
- Merges multiple policy documents, if required
- Configure bucket ACLs, if required
- Configure replication and IAM role, if required
- Create S3 access points, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> **IMPORTANT:**

- As of version `2.2.0`, default request metrics and alarms based on [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#S3) will be automatically created. This will incur an extra charge of up to $1.90 per month (this includes the $1.60 for request metrics) for each S3 bucket. To disable the creation of these metrics and alarms, please set the variable `disable_default_alarms` to `true`.

- As of version `2.4.0` a trust policy has been added to the IAM module which denies access to assume the created role outside of the Experian AWS Organization. Note that the IAM role is only created in this module when replication is enabled. If this breaks your use case, disable this functionality by setting the variable `disable_org_check` to `true`.

- As of version `2.5.0` a default bucket policy has been added that denies any access to source IPs not originating from the EEC approved CIDR list. This policy will ignore aws services, local s3 vpc endpoint gateways (additional may be added with `allowed_source_vpce_ids`) and tagged exceptions. You may disable this behaviour with the `disable_source_ip_check` variable.
  - As of version `2.9.1`, the new SkyHigh proxy static IPs have been added.

- As of version `2.14.0`, a default lifecycle rule is now automatically added to abort incomplete multipart uploads after a configurable number of days (default: 7), in line with AWS cost optimization best practices. This helps reduce unnecessary storage costs.
  - To disable this behavior, set `enable_abort_incomplete_multipart_upload` to `false`.
  - To change the default number of days, use the `default_abort_incomplete_multipart_upload_days` variable.

## EITS Security & Compliance

**Last Module Review**: 2026-06-30

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-07-01 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-07-01 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-07-01 | 0.70.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-07-01 | 1.47.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## SSE Encryption

This S3 module requires Server-Side Encryption configuration, unencrypted buckets are not supported. See [Setting default server-side encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html) for aws guidance.

By default AES256/SSE-S3 is configured if no encryption related configuration is supplied. This is the recommended approach for most buckets.

If you wish to use SSE-KMS, set `sse_algorithm="aws:kms"` and `kms_key_arn="<arn of existing kms key>"`. When using a key to encrypt it's recommended to use a customer managed KMS key, rather than the AWS Managed KMS S3 Key.

To create a KMS key you can use the [eits-tf-aws-kms](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-kms/browse) module and pass the arn to this one, for example:

```hcl
sse_algorithm = "aws:kms"
kms_key_arn   = module.kms_key.key_arn
```

S3 Bucket Key is automatically configured for all types of encryption, see [Reducing the cost of SSE-KMS with Amazon S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html) for details.

## Using ACLs

The default bucket ownership is set to "Bucket owner enforced" which disables the use of ACLs. Bucket ACLs are deprecated by AWS in favour of bucket policies. [Learn more here](https://docs.aws.amazon.com/console/s3/object-ownership-bucket-owner-enforced).

To use ACLs change `object_ownership` to either `BucketOwnerPreferred` or `ObjectWriter` and use either a [canned acl](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl) with `acl_canned` or set the `acl_grants` variable to pass then, for example:

```hcl
acl_grants = [
  {
    id          = data.aws_canonical_user_id.current.id
    type        = "CanonicalUser"
    permissions = ["READ"]
  },
  {
    type        = "Group"
    permissions = ["READ_ACP"]
    uri         = "http://acs.amazonaws.com/groups/s3/LogDelivery"
  }
]
```

## IAM Policy Documents

There are two variables to handle bucket IAM policy: `bucket_policy` and `source_policy_documents`.

To pass a json file path or json string use `bucket_policy`, for example:

```hcl
bucket_policy = "policy.json"
```

If you wish to pass aws_iam_policy_document data sources, pass a list to `source_policy_documents`, for example:

```hcl
source_policy_documents = [data.aws_iam_policy_document.document_1.json, data.aws_iam_policy_document.document_2.json]
```

The policies from both variables will be merged and attached to the bucket as a single bucket policy.

## Replication

This module is able to configure replication for a source S3 bucket. To use this you will need to have created an appropriate destination S3 bucket for the replicas to be sent, an example of this can be found in the "tests/with_replication" and "tests/with_kms_replication" directories. The reason for this is to allow the module to be used for multi-region and cross-account configurations if necessary. When using multi-region replication please be aware of GDPR compliance, see [AWS Docs](https://aws.amazon.com/compliance/gdpr-center/).

To turn on replication, use the `replication_config` variable as follows:

```hcl
replication_config = {
  enabled = true (mandatory)

  # destination config
  destination_bucket_arn = "<arn of destination s3 bucket>" (mandatory)
  destination_region     = "<defaults to same region as source, but can be overridden here>"
  storage_class          = "<storage class of replica objects>"

  # enable kms encryption, both variables below are required if enabling, omit of not required
  enable_kms_encryption = true
  replica_kms_key_id    = "<kms key arn for the destination bucket/objects>"

  # set both of the following if you want objects to not be owned by source, omit if not required
  replica_owner   = "Destination"
  replica_account = "<account id for destination bucket>"

  # list of replication rules, at least one is required
  rules = [
    {
      id                        = "<unique id of rule>" (mandatory) 
      priority                  = <priority number, mandatory if multiple rules with filter>

      delete_marker_replication = "<Disabled/Enabled>"
      replica_modifications     = "<Disabled/Enabled>"

      # filter map must be omitted if none is required
      # if filter is used, map must have ONE of the following keys: prefix, and, or tag
      # this example shows all three, use only one!
      filter = {
        prefix = "<object key name prefix>"
        tags = [
          {
            key   = "<name of the object key>"
            value = "<value of the tag>"
          }
        ]
        and = [
          {
            prefix = "<object key name prefix>"
            tags   = {<map of tag key and value pairs>}
          }
        ]

      }
    }
  ]

}
```

Some notes on replication configuration:

- The `enabled` value must be set to `true` for replication to be configured.
- Any key that does not specify "(mandatory)" in the example above may be omitted.
- The `replication_config` must be specified in the source region, for the source bucket.
- Only one destination bucket is supported by this module. This is in order for the module is able to configure IAM permissions. To configure replication to multiple buckets, do not use the `replication_config` variable and create the [s3_bucket_replication_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.0.0/docs/resources/s3_bucket_replication_configuration) resource and iam roles/policies, etc, outside of this module. 
- Default metrics and alarms will automatically be created for each replication rule, unless `disable_default_alarms` is set to `true`.
- At least one rule map in the `rules` list is required. Multiple rules may be provided. See [s3_bucket_replication_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.0.0/docs/resources/s3_bucket_replication_configuration#rule) for more details on values. The `priority` value must be set if there are multiple `filter` rules.
- If no filter is required, do not pass the `filter` argument. If filter is required, use only ONE of either "prefix", "add", or "tags" keys under the `filter` argument. See above for examples of each.
- The `delete_marker_replication` value defaults to `Disabled`. This is due to cross-region replication and tag filter compatibility. S3 does not support replicating delete markers for tag-based rules.
- Replica objects are automatically owned by source account unless `replica_owner` is set to "Destination" and `replica_account` is populated (see example above).
- Replica object storage class defaults to `STANDARD`, see [StorageClass](https://docs.aws.amazon.com/AmazonS3/latest/API/API_Destination.html#AmazonS3-Type-Destination-StorageClass) for all accepted values.
- To enable KMS encryption for replica objects/buckets, both `enable_kms_encryption=true` and `replica_kms_key_id` are required to be set.
- Replication does not support multi-region KMS keys, when attempting cross-region replication you will need to set up keys in each region (see "tests/with_kms_replication" directory for an example). Make sure to grant the replication IAM role ("BURoleForReplication-source_bucket_name") encrypt/decrypt permissions to these keys. You will have to do this using the condition block rather than principle as the IAM role won't exist before you create the kms key (again, see tests directory for an example). For more information on the required KMS key/IAM permissions see [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-config-for-kms-objects.html#replications).

## USAGE

```hcl
module "s3" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git"

  # Bucket properties
  bucket_name                = "<bucket_name>"
  access_logging_bucket_name = "<bucket_name>"

  # Bucket policy
  source_policy_documents = ["<list of IAM policy documents (in json) that will be merged together (e.g. from aws_iam_policy_document)>"]

  # Encryption configuration (omit if AES256/SSE-S3 is required, see above)
  sse_algorithm = "aws:kms"
  kms_key_arn   = "<kms_key_arn>"

  # Intelligent tiering (if required, otherwise omit)
  intelligent_tiering = {
    devtest = {
      status = "Enabled"
      filter = {
        tags = {
          Environment = "<env>"
        }
      }
      tiering = {
        ARCHIVE_ACCESS = {
          days = <days> # can't be less than 90 for Archive
        }
      }
    }
  }

  # Lifecycle rules (if required, otherwise omit)
  lifecycle_rules = [
    {
      id     = "<id>"
      status = "Enabled"

      filter = {
        tags = {
          log = "yes"
        }
      }

      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 60
          storage_class = "ONEZONE_IA"
        }
      ]

      expiration = {
        days = 90 # Conflicts with 'expired_object_delete_marker'
      }

      noncurrent_version_expiration = {
        newer_noncurrent_versions = 1
        noncurrent_days           = 30
      }
    },
    { # Archive and delete old versions
      id     = "<id>"
      status = "Enabled"

      filter = {
        tags = {
          backup_type  = "<backup_type>"
          backup_level = "<backup_level>"
        }
      }

      noncurrent_version_transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]

      noncurrent_version_expiration = {
        noncurrent_days = 60
      }
    }
  ]

  # Tags
  tags = {
    Environment = <env>
    CostString  = <CostString>
    AppID       = <AppID>
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.46.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.46.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_replication_iam_role"></a> [replication\_iam\_role](#module\_replication\_iam\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam | 1.9.7 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role_policy.replication_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_access_point.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_access_point) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_metric.entire_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_metric) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3control_access_point_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_point_policy) | resource |
| [time_sleep.wait_for_s3_bucket](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_canonical_user_id.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/canonical_user_id) | data source |
| [aws_iam_policy_document.block_nonsecure_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replica_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication_combined](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.restrict_source_ips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.source_documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.source_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc_endpoint.s3_gateways](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint) | data source |
| [aws_vpcs.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logging_bucket_name"></a> [access\_logging\_bucket\_name](#input\_access\_logging\_bucket\_name) | Defines the target bucket for logging. | `string` | `null` | no |
| <a name="input_access_points"></a> [access\_points](#input\_access\_points) | A list of S3 Access Points to create for the bucket. Please note there are limitations with using access points, see [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html) for more information. Usage:<br><pre>access\_points = [<br> {<br>    name                    = Unique name you want to assign to this access point. See [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-access-points.html?icmpid=docs_amazons3_console#access-points-names) for naming conditions.<br>    policy                  = Valid JSON document that specifies the policy that you want to apply to this access point, see [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points-policies.html?icmpid=docs_amazons3_console).<br>    restricted\_vpc\_id       = Restrict access to this access point to requests from the specified VPC.<br>    block\_public\_acls       = Whether to block public ACLs. Defaults to 'true'.<br>    block\_public\_policy     = Whether to block public bucket policies. Defaults to 'true'.<br>    ignore\_public\_acls      = Whether to ignore public ACLs. Defaults to 'true'.<br>    restrict\_public\_buckets = Whether to restrict public buckets. Defaults to 'true'.<br>  }<br>]</pre> | <pre>list(object({<br>    name                    = string<br>    policy                  = optional(string)<br>    restricted_vpc_id       = optional(string)<br>    block_public_acls       = optional(bool, true)<br>    block_public_policy     = optional(bool, true)<br>    ignore_public_acls      = optional(bool, true)<br>    restrict_public_buckets = optional(bool, true)<br>  }))</pre> | `[]` | no |
| <a name="input_acl_canned"></a> [acl\_canned](#input\_acl\_canned) | The canned ACL to apply, [see here](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl). Deprecated by AWS in favour of bucket policies. Is ignored when `acl_grants` is set or `object_ownership` is set to `BucketOwnerEnforced` (default). | `string` | `"private"` | no |
| <a name="input_acl_grants"></a> [acl\_grants](#input\_acl\_grants) | The access control policy to apply. Deprecated by AWS in favour of bucket policies. Is ignored when `object_ownership` is set to `BucketOwnerEnforced` (default). Will overwrite value in `acl_canned`. Requires a list of policy grants for the bucket, taking a list of permissions | <pre>list(<br>    object({<br>      id          = optional(string)<br>      type        = string<br>      permissions = list(string)<br>      uri         = optional(string)<br>    })<br>  )</pre> | `[]` | no |
| <a name="input_alarm_metric_thresholds"></a> [alarm\_metric\_thresholds](#input\_alarm\_metric\_thresholds) | A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#S3) for a list of metrics, the name of the metric is the key to use when setting a threshold | <pre>object({<br>    Average4xxErrors = optional(number)<br>    Average5xxErrors = optional(number)<br>    OperationsFailedReplication = optional(object({<br>      DestinationBucket = optional(string)<br>      RuleIdList        = optional(list(string))<br>      threshold         = optional(number)<br>    }))<br>  })</pre> | `{}` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_allowed_source_vpce_ids"></a> [allowed\_source\_vpce\_ids](#input\_allowed\_source\_vpce\_ids) | List of VPC Endpoint IDs to allow access to the bucket. The local regional S3 VPCE gateway will automatically be added unless `disable_source_vpce_check` is `true`. Not used if `disable_source_ip_check` is `true` | `list(string)` | `[]` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the bucket, must be unique. | `string` | n/a | yes |
| <a name="input_bucket_policy"></a> [bucket\_policy](#input\_bucket\_policy) | Accepts either a relative path for a bucket policy json file, or direct json (e.g. from aws\_iam\_policy\_document). Policy will be merged with `source_policy_documents` if also supplied. | `string` | `null` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_default_abort_incomplete_multipart_upload_days"></a> [default\_abort\_incomplete\_multipart\_upload\_days](#input\_default\_abort\_incomplete\_multipart\_upload\_days) | Number of days after which incomplete multipart uploads are aborted when 'enable\_abort\_incomplete\_multipart\_upload' is 'true' and no per-rule override is provided. | `number` | `7` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#S3). Please note bucket request metrics will be disabled if this is set to `true` | `bool` | `false` | no |
| <a name="input_disable_org_check"></a> [disable\_org\_check](#input\_disable\_org\_check) | Set this to `true` to remove the default trust policy which stops roles from outside the Experian Organization from assuming the replication IAM role. Only applicable if `replication_config` is enabled | `bool` | `false` | no |
| <a name="input_disable_source_ip_check"></a> [disable\_source\_ip\_check](#input\_disable\_source\_ip\_check) | Set this to `true` to remove default bucket policy that denies any access to source IPs not originating from the EEC approved CIDR list | `bool` | `false` | no |
| <a name="input_disable_source_vpce_check"></a> [disable\_source\_vpce\_check](#input\_disable\_source\_vpce\_check) | Set this to `true` for non-EEC compliant accounts, and if your terraform returns a `no matching EC2 VPC Endpoint found` error. Already disabled if `disable_source_ip_check` is `true` | `bool` | `false` | no |
| <a name="input_enable_abort_incomplete_multipart_upload"></a> [enable\_abort\_incomplete\_multipart\_upload](#input\_enable\_abort\_incomplete\_multipart\_upload) | Whether to enable a default lifecycle rule to abort incomplete multipart uploads. If 'true', 'default\_abort\_incomplete\_multipart\_upload\_days' will be used unless overridden per rule. | `bool` | `true` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable. | `bool` | `false` | no |
| <a name="input_intelligent_tiering"></a> [intelligent\_tiering](#input\_intelligent\_tiering) | A map of maps containing intelligent tiering configuration. The map key will be used to name the configuration. Note that the map key for `tiering` must be either `ARCHIVE_ACCESS` or `DEEP_ARCHIVE_ACCESS`.See [s3\_bucket\_intelligent\_tiering\_configuration](https://registry.terraform.io/providers/-/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) for guidance on values | <pre>map(<br>    object({<br>      status = optional(string, "Enabled")<br>      filter = optional(object({<br>        prefix = optional(string)<br>        tags   = optional(map(string))<br>      }))<br>      tiering = optional(map(<br>        object({<br>          days = optional(number)<br>        })<br>      ), {})<br>    })<br>  )</pre> | `{}` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of an existing AWS KMS key. Must be set if `sse_algorithm` is set to `aws:kms`. | `string` | `null` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | A list of maps defining the lifecycle rules for the bucket. See [s3\_bucket\_lifecycle\_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration#argument-reference) for guidance on values. Note that if no `rule.filter` value is set, it will default to filtering objects with an empty string prefix | <pre>list(<br>    object({<br>      id                                     = optional(string)<br>      status                                 = optional(string, "Enabled")<br>      abort_incomplete_multipart_upload_days = optional(number)<br>      expiration = optional(object({<br>        date                         = optional(string)<br>        days                         = optional(number)<br>        expired_object_delete_marker = optional(bool)<br>      }))<br>      filter = optional(object({<br>        prefix                   = optional(string)<br>        object_size_greater_than = optional(number)<br>        object_size_less_than    = optional(number)<br>        tags                     = optional(map(string), {})<br>      }), {})<br>      noncurrent_version_expiration = optional(object({<br>        newer_noncurrent_versions = optional(number)<br>        noncurrent_days           = optional(number)<br>      }))<br>      noncurrent_version_transition = optional(list(<br>        object({<br>          newer_noncurrent_versions = optional(number)<br>          noncurrent_days           = optional(number)<br>          storage_class             = optional(string)<br>        })<br>      ), [])<br>      transition = optional(list(<br>        object({<br>          date          = optional(string)<br>          days          = optional(number)<br>          storage_class = optional(string)<br>        })<br>      ), [])<br>    })<br>  )</pre> | `[]` | no |
| <a name="input_logging_key_format_partitioned_prefix"></a> [logging\_key\_format\_partitioned\_prefix](#input\_logging\_key\_format\_partitioned\_prefix) | Setting this enables the partitioned prefix format for logging object key. The partition\_date\_source is required and can be only one of ['EventTime', 'DeliveryTime'] | <pre>object({<br>    partition_date_source = string<br>  })</pre> | `null` | no |
| <a name="input_object_lock_configuration"></a> [object\_lock\_configuration](#input\_object\_lock\_configuration) | Configuration block for specifying the default Object Lock retention settings for new objects placed in the specified bucket. You cannot disable S3 Object Lock or S3 Versioning for buckets once S3 Object Lock is enabled.<br>  Values:<br>  `mode`  - (Required) Default Object Lock retention mode you want to apply to new objects placed in the specified bucket. Valid values: `COMPLIANCE` or `GOVERNANCE`.<br>  `days`  - (Optional, Required if `years` is not specified) Number of days that you want to specify for the default retention period.<br>  `years` - (Optional, Required if `days` is not specified) Number of years that you want to specify for the default retention period.<br>  See the [Terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration#default_retention) and the [AWS Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html) for more information" | <pre>object({<br>    mode  = string<br>    days  = optional(number)<br>    years = optional(number)<br>  })</pre> | `null` | no |
| <a name="input_object_ownership"></a> [object\_ownership](#input\_object\_ownership) | Object ownership. Valid values are `BucketOwnerPreferred`, `ObjectWriter` or `BucketOwnerEnforced`. `BucketOwnerEnforced` is not compatible with the acl\_* variables. | `string` | `"BucketOwnerEnforced"` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | ARN of an IAM policy to use as a permissions boundary for the replication IAM role. Required in environments where CI/Jenkins enforces boundaries on role creation. | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Optional prefix for the bucket name. When set, the full bucket name is constructed as `{prefix}-{bucket_name}-s3`. When null (default), `bucket_name` is used as-is. | `string` | `null` | no |
| <a name="input_public_access_config"></a> [public\_access\_config](#input\_public\_access\_config) | A map of public access config, defaults to all values being `true` | <pre>object({<br>    block_public_acls       = optional(bool, true)<br>    block_public_policy     = optional(bool, true)<br>    ignore_public_acls      = optional(bool, true)<br>    restrict_public_buckets = optional(bool, true)<br>  })</pre> | `{}` | no |
| <a name="input_replication_config"></a> [replication\_config](#input\_replication\_config) | Replication configuration, see README.md for details | <pre>object({<br>    enabled                = optional(bool, false)<br>    destination_bucket_arn = optional(string)<br>    destination_region     = optional(string)<br>    storage_class          = optional(string, "STANDARD")<br>    replica_owner          = optional(string)<br>    replica_account        = optional(string)<br>    enable_kms_encryption  = optional(bool, false)<br>    replica_kms_key_id     = optional(string)<br>    rules = optional(list(<br>      object({<br>        id                        = optional(string)<br>        status                    = optional(string, "Enabled")<br>        priority                  = optional(number)<br>        delete_marker_replication = optional(string, "Disabled")<br>        replica_modifications     = optional(string, "Disabled")<br>        filter = optional(object({<br>          prefix = optional(string)<br>          and = optional(list(<br>            object({<br>              prefix = optional(string)<br>              tags   = optional(map(string))<br>            })<br>          ))<br>          tags = optional(list(<br>            object({<br>              key   = optional(string)<br>              value = optional(string)<br>            })<br>          ))<br>        }))<br>      })<br>    ))<br>  })</pre> | `{}` | no |
| <a name="input_replication_role_attach_policy_inline"></a> [replication\_role\_attach\_policy\_inline](#input\_replication\_role\_attach\_policy\_inline) | When set to true, Replication role permissions are attached as an inline role policy instead of a standalone managed policy. Use this when your environment restricts creation of IAM managed policies. | `bool` | `false` | no |
| <a name="input_replication_role_name"></a> [replication\_role\_name](#input\_replication\_role\_name) | Exact IAM role/policy name to use for the replication role. When null (default), the module auto-generates the name as `Replication-{bucket_name}`. | `string` | `null` | no |
| <a name="input_source_policy_documents"></a> [source\_policy\_documents](#input\_source\_policy\_documents) | List of IAM policy documents (in json) that will be merged together (e.g. from aws\_iam\_policy\_document). All statements must have unique SIDs. Does not support json files. Policy will be merged with `bucket_policy` if also supplied. | `list(any)` | `[]` | no |
| <a name="input_sse_algorithm"></a> [sse\_algorithm](#input\_sse\_algorithm) | Server-side encryption algorithm to use. Valid values are `AES256` or `aws:kms`. | `string` | `"AES256"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags. | `map(string)` | `{}` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Defines whether bucket versioning is enables or disabled, enabled by default. If replication is enabled, versioning will be automatically enabled | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_replication_iam_role_arn"></a> [replication\_iam\_role\_arn](#output\_replication\_iam\_role\_arn) | ARN for the IAM role created for replication configuration. |
| <a name="output_replication_policy_json"></a> [replication\_policy\_json](#output\_replication\_policy\_json) | Combined replication IAM policy JSON. Populated regardless of `replication_role_attach_policy_inline` so callers can attach it manually if needed. Empty string when replication is disabled. |
| <a name="output_replication_role_name"></a> [replication\_role\_name](#output\_replication\_role\_name) | Name of the IAM role created for replication. Empty string when replication is disabled. |
| <a name="output_s3_access_points"></a> [s3\_access\_points](#output\_s3\_access\_points) | Map of created S3 access points and their configuration. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the bucket. Will be of format arn:aws:s3:::bucketname. |
| <a name="output_s3_bucket_domain_name"></a> [s3\_bucket\_domain\_name](#output\_s3\_bucket\_domain\_name) | Bucket domain name. Will be of format bucketname.s3.amazonaws.com. |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | The name of the bucket. |
| <a name="output_s3_bucket_regional_domain_name"></a> [s3\_bucket\_regional\_domain\_name](#output\_s3\_bucket\_regional\_domain\_name) | The bucket region-specific domain name, including the region name. |
| <a name="output_s3_hosted_zone"></a> [s3\_hosted\_zone](#output\_s3\_hosted\_zone) | Route 53 Hosted Zone ID for this bucket's region. |
| <a name="output_s3_region"></a> [s3\_region](#output\_s3\_region) | AWS region this bucket resides in. |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS S3 buckets
region: Global
bu: EITS
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```
