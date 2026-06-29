variable "aliases" {
  type        = list(string)
  description = "An array DNS alias names that you want to associate with the Amazon FSx file system."
  default     = []
}

variable "audit_log_configuration" {
  type = object({
    audit_log_destination             = optional(string)
    file_access_audit_log_level       = optional(string, "FAILURE_ONLY")
    file_share_access_audit_log_level = optional(string, "FAILURE_ONLY")
  })
  description = <<EOT
  The configuration that Amazon FSx for Windows File Server uses to audit and log user accesses of files, folders, and file shares on the file system.
  <pre>audit_log_configuration = {
    audit_log_destination - (Optional) The ARN for the destination of the audit logs. 
                            The destination can be any Amazon CloudWatch Logs log group ARN or Amazon Kinesis Data Firehose delivery stream ARN. 
                            Can be specified when <i>file_access_audit_log_level</i> and <i>file_share_access_audit_log_level</i> are not set to <i>DISABLED</i>. 
                            The name of the Amazon CloudWatch Logs log group must begin with the <i>/aws/fsx</i> prefix. 
                            The name of the Amazon Kinesis Data Firehouse delivery stream must begin with the <i>aws-fsx</i> prefix. 
                            If you do not provide a destination in <i>audit_log_destionation</i>, Amazon FSx will create and use a log stream in the CloudWatch Logs <i>/aws/fsx/windows</i> log group.
    file_access_audit_log_level - (Optional) Sets which attempt type is logged by Amazon FSx for file and folder accesses. 
                                  Valid values are <i>SUCCESS_ONLY</i>, <i>FAILURE_ONLY</i>, <i>SUCCESS_AND_FAILURE</i>, and <i>DISABLED</i>. Default value is <i>DISABLED</i>.
    file_share_access_audit_log_level - (Optional) Sets which attempt type is logged by Amazon FSx for file share accesses. 
                                        Valid values are <i>SUCCESS_ONLY</i>, <i>FAILURE_ONLY</i>, <i>SUCCESS_AND_FAILURE</i>, and <i>DISABLED</i>. Default value is <i>DISABLED</i>.
  }</pre>
  EOT
  default     = {}
}

variable "automatic_backup_retention_days" {
  type        = number
  description = "The number of days to retain automatic backups. Minimum of `0` and maximum of `90`. Set to `0` to disable."
  default     = 30
}

variable "backup_id" {
  type        = string
  description = "The ID of the source backup to create the filesystem from."
  default     = null
}

variable "copy_tags_to_backups" {
  type        = bool
  description = "A boolean flag indicating whether tags on the file system should be copied to backups."
  default     = false
}

variable "create_cloudwatch_log_group" {
  type        = bool
  description = "Determines whether a default log group is created."
  default     = true
}

variable "cloudwatch_log_group_retention" {
  type        = number
  description = "Number of days to retain logs in the CloudWatch log group. Defaults to `90` for production and `30` for non-production environments if not specified."
  default     = null
}

variable "create_kms_key" {
  type        = bool
  description = "Determines whether a default KMS key is created. A KMS CMK key is required for production environments."
  default     = false
}

variable "daily_automatic_backup_start_time" {
  type        = string
  description = "The preferred time (in `HH:MM` format) to take daily automatic backups, in the UTC time zone."
  default     = null
}

variable "deployment_type" {
  type        = string
  description = <<EOT
  Specifies the file system deployment type, valid values are `MULTI_AZ_1`, `SINGLE_AZ_1` and `SINGLE_AZ_2`. 
  Enforced to `MULTI_AZ_1` for Production environment.
  EOT
  default     = null
}

variable "disk_iops_configuration" {
  type = object({
    iops = optional(number)
    mode = optional(string)
  })
  description = <<EOT
  The SSD IOPS configuration for the Amazon FSx for Windows File Server file system
  <pre>disk_iops_configuration = {
    iops - (Optional) The total number of SSD IOPS provisioned for the file system.
    mode - (Optional) Specifies whether the number of IOPS for the file system is using the system. 
           Valid values are <i>AUTOMATIC</i> and <i>USER_PROVISIONED</i>. Default value is <i>AUTOMATIC</i>.
  }</pre>
  EOT
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "ARN for the KMS Key to encrypt the file system at rest. Defaults to an AWS managed KMS Key."
  default     = null
}

variable "name" {
  type        = string
  description = "The name of the file system."
  default     = ""
}

variable "preferred_subnet_id" {
  type        = string
  description = <<EOT
  Specifies the subnet in which you want the preferred file server to be located. 
  Required for when deployment type is `MULTI_AZ_1`.
  EOT
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = <<EOT
  A list of IDs for the security groups that apply to the specified network interfaces created for file system access. 
  These security groups will apply to all network interfaces.
  EOT
  default     = []
}

variable "self_managed_active_directory" {
  type = object({
    dns_ips                                = list(string)
    domain_name                            = string
    file_system_administrators_group       = optional(string)
    organizational_unit_distinguished_name = optional(string)
    username                               = string
    password                               = string
  })
  description = <<EOT
  Configuration block that Amazon FSx uses to join the Windows File Server instance to your self-managed (including on-premises) Microsoft Active Directory.
  <pre>self_managed_active_directory = {
    dns_ips - (Required) A list of up to two IP addresses of DNS servers or domain controllers in the self-managed AD directory. 
              The IP addresses need to be either in the same VPC CIDR range as the file system or in the private IP version 4 (IPv4) address ranges as specified in [RFC 1918](https://tools.ietf.org/html/rfc1918).
    domain_name - (Required) The fully qualified domain name of the self-managed AD directory. For example, <i>uk.experian.local</i>.
    username - (Required) The user name for the service account on your self-managed AD domain that Amazon FSx will use to join to your AD domain.
    password - (Required) The password for the service account on your self-managed AD domain that Amazon FSx will use to join to your AD domain. 
               Please don't store this in plain text!
    file_system_administrators_group - (Optional) The name of the domain group whose members are granted administrative privileges for the file system. 
    Administrative privileges include taking ownership of files and folders, and setting audit controls (audit ACLs) on files and folders. 
    The group that you specify must already exist in your domain. Defaults to <i>Domain Admins</i>.
    organizational_unit_distinguished_name - (Optional) The FQDN of the organizational unit within your self-managed AD directory that the Windows File Server instance will join. 
    For example, <i>OU=FSx,DC=uk,DC=experian,DC=local</i>. Only accepts OU as the direct parent of the file system. 
    If none is provided, the FSx file system is created in the default location of your self-managed AD directory. 
    To learn more, see [RFC 2253](https://tools.ietf.org/html/rfc2253).
  }</pre>
  EOT
  sensitive   = true
}

variable "skip_final_backup" {
  type        = bool
  description = <<EOT
  When enabled, will skip the default final backup taken when the file system is deleted. 
  This configuration must be applied separately before attempting to delete the resource to have the desired behavior.
  EOT
  default     = false
}

variable "storage_capacity" {
  type        = number
  description = <<EOT
  Storage capacity (GiB) of the file system. Minimum of `32` and maximum of `65536`. 
  If the storage type is set to HDD the minimum value is `2000`. Required when not creating filesystem for a backup.
  EOT
  default     = 32
}

variable "storage_type" {
  type        = string
  description = <<EOT
  Specifies the storage type, Valid values are `SSD` and `HDD`. 
  `HDD` is supported on `SINGLE_AZ_2` and `MULTI_AZ_1` Windows file system deployment types.
  EOT
  default     = "SSD"
}

variable "subnet_ids" {
  type        = list(string)
  description = <<EOT
  A list of IDs for the subnets that the file system will be accessible from. 
  To specify more than a single subnet set `deployment_type` to `MULTI_AZ_1`.
  EOT
}

variable "throughput_capacity" {
  type        = number
  description = "Throughput (megabytes per second) of the file system in power of `2` increments. Minimum of `8` and maximum of `2048`."
}

variable "timeouts" {
  type = object({
    create = optional(string, "60m")
    delete = optional(string, "30m")
    update = optional(string, "45m")
  })
  description = <<EOT
  `create`, `update`, and `delete` timeout configurations for the file system.
  <pre>timeouts = {
    create - (Default 60m)
    delete - (Default 30m)
    update - (Default 45m)
  }</pre>
  EOT
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = <<EOT
  The ID of the VPC in which the file system will be created. If not specified, the VPC will be automatically selected. 
  Please note that this would only work if there is only one VPC in the region. If you have multiple VPCs, you must specify the VPC ID.
  EOT
  default     = null
}

variable "weekly_maintenance_start_time" {
  type        = string
  description = "The preferred start time (in `d:HH:MM` format) to perform weekly maintenance, in the UTC time zone. Defaults to `Sunday 11pm`."
  default     = "7:23:00"
}

variable "alarm_sns_topics" {
  type        = list(string)
  description = "List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions"
  default     = []
}

variable "enable_default_alarms" {
  type        = bool
  description = "Set to `true` to enable FSx default utilization alarms"
  default     = false
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions, if enabled."
  default     = false
}

variable "alarm_thresholds" {
  type = object({
    storage_capacity_utilization = optional(number, 85)
    network_capacity_utilization = optional(number, 85)
    disk_iops_utilization        = optional(number, 85)
    fs_disk_iops_utilization     = optional(number, 85)
  })
  description = <<EOT
  Threshold for the default utilization alarms (in %).
  <pre>alarm_thresholds = {
    storage_capacity_utilization (Default 85)
    network_capacity_utilization (Default 85)
    disk_iops_utilization        (Default 85)
    fs_disk_iops_utilization     (Default 85)
  }</pre>
  EOT
  default     = {}
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to add to all resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags."
  default     = {}
}
