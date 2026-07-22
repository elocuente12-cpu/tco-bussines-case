locals {
  common_tags = {
    Terraform       = true
    Team            = var.team
    Server          = var.server
    BusinessUnit    = "FSD"
    map-migrated    = "migQQS9IAS1YO"
    Project         = "PRJ0168817"
    Product         = "Preciseid"
    Purpose         = "Resilience"
    AppID           = "25732"
    Environment     = "stg"
    CostString      = "1100.us.624.402026.66004000"
    SecurityClass   = "confidential"
    Author          = "Terraform"
    eec-ami-account = "363353661606"
    Owner           = "cis-dps-platform-engineering@experian.com"
    account_id      = "131646119455"
    ManagedBy       = "terraform"
    Client          = "multi"
    Region          = "NA"

  }

  name           = "${var.team}-${var.server}"
  workspace_key  = terraform.workspace
  base_workspace = trimsuffix(terraform.workspace, "_west")

  # If a west-specific key does not exist in a map, use the base workspace (e.g. stage_west -> stage).
  instance_types    = lookup(var.instance_types, local.workspace_key, lookup(var.instance_types, local.base_workspace, var.instance_types["stage"]))
  root_volume_size  = lookup(var.root_volume_size, local.workspace_key, lookup(var.root_volume_size, local.base_workspace, var.root_volume_size["stage"]))
  volume_size       = lookup(var.volume_size, local.workspace_key, lookup(var.volume_size, local.base_workspace, var.volume_size["stage"]))
  min_size          = lookup(var.min_size, local.workspace_key, lookup(var.min_size, local.base_workspace, var.min_size["stage"]))
  max_size          = lookup(var.max_size, local.workspace_key, lookup(var.max_size, local.base_workspace, var.max_size["stage"]))
  desired_capacity  = lookup(var.desired_capacity, local.workspace_key, lookup(var.desired_capacity, local.base_workspace, var.desired_capacity["stage"]))
  cpu_target_value  = lookup(var.cpu_target_value, local.workspace_key, lookup(var.cpu_target_value, local.base_workspace, var.cpu_target_value["stage"]))
  asg_instance_name = "${var.team}-${var.asg_instance_name}-${terraform.workspace}"
  user_data_path    = lookup(var.user_data_path, local.workspace_key, lookup(var.user_data_path, local.base_workspace, var.user_data_path["stage"]))

  # East uses useast proxy, west workspaces use uswest proxy.
  proxy_host = try(
    {
      stage      = "proxy-useast.us.experian.eeca"
      uat        = "proxy-useast.us.experian.eeca"
      prod       = "proxy-useast.us.experian.eeca"
      stage_west = "proxy-uswest.us.experian.eeca"
      uat_west   = "proxy-uswest.us.experian.eeca"
      prod_west  = "proxy-uswest.us.experian.eeca"
    }[local.workspace_key],
    {
      stage      = "proxy-useast.us.experian.eeca"
      uat        = "proxy-useast.us.experian.eeca"
      prod       = "proxy-useast.us.experian.eeca"
      stage_west = "proxy-uswest.us.experian.eeca"
      uat_west   = "proxy-uswest.us.experian.eeca"
      prod_west  = "proxy-uswest.us.experian.eeca"
    }[local.base_workspace],
    "proxy-useast.us.experian.eeca"
  )

  # East uses existing bucket, west uses west bucket.
  ami_docs_bucket = try(
    {
      stage      = "eec-stg-delorean-ami-docs"
      stage_west = "eec-stg-delorean-ami-docs-west"
    }[local.workspace_key],
    {
      stage      = "eec-stg-delorean-ami-docs"
      stage_west = "eec-stg-delorean-ami-docs-west"
    }[local.base_workspace],
    "eec-stg-delorean-ami-docs"
  )

  imageBuilderComponents = length(var.imageBuilderComponents) > 0 ? var.imageBuilderComponents : [
    {
      "name"        = "Deploy digital envoy Scripts"
      "description" = "deploy scripts and add cron entries"
      "version"     = "1.0.28"
      "data" = yamlencode({
        schemaVersion = 1.0
        phases = [
          {
            name = "build"
            steps = [
              {
                name   = "set_proxy"
                action = "ExecuteBash"
                inputs = {
                  commands = [
                    "set -euo pipefail",
                    "echo '=== Configuring proxy for build ==='",
                    "echo \"[INFO] Proxy selected for workspace ${local.workspace_key}: ${local.proxy_host}:9595\"",
                    "cat >/etc/profile.d/proxy.sh <<'EOF'",
                    "export http_proxy=http://${local.proxy_host}:9595",
                    "export https_proxy=http://${local.proxy_host}:9595",
                    "export no_proxy=localhost,127.0.0.1,.svc,.cluster.local,kubernetes.default.svc,169.254.169.254",
                    "EOF",
                    "chmod 644 /etc/profile.d/proxy.sh",
                    "source /etc/profile.d/proxy.sh",
                    "echo 'proxy='\"$http_proxy\" >> /etc/yum.conf",
                    "echo '=== Proxy configured successfully ==='"
                  ]
                }
              },
              {
                name   = "create_groups_and_users"
                action = "ExecuteBash"
                inputs = {
                  commands = [
                    "set -x",
                    "SECONDS=0",
                    "echo \"[INFO] create_groups_and_users started at $(date -u +%Y-%m-%dT%H:%M:%SZ)\"",
                    "groupadd -g 20600 sysint",
                    "groupadd -g 1600 cm",
                    "useradd -u 20602 -g 20600 -m -s /bin/bash siadmin",
                    "usermod -aG cm siadmin",
                    "useradd -u 1600 -g 1600 -m -s /bin/bash sl000cm",
                    "echo \"Group 'sysint':\"",
                    "getent group sysint",
                    "echo \"Group 'cm':\"",
                    "getent group cm",
                    "echo \"User 'siadmin':\"",
                    "id siadmin",
                    "echo \"User 'sl000cm':\"",
                    "id sl000cm",
                    "echo \"[INFO] create_groups_and_users completed in $SECONDS s at $(date -u +%Y-%m-%dT%H:%M:%SZ)\""
                  ]
                }
              },
              {
                name   = "install_java"
                action = "ExecuteBash"
                inputs = {
                  commands = [
                    "SECONDS=0",
                    "echo \"[INFO] install_java started at $(date -u +%Y-%m-%dT%H:%M:%SZ)\"",
                    "echo \"Installing Java 17\"",
                    "yum install -y java-17-amazon-corretto-devel",
                    "export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64",
                    "export PATH=$JAVA_HOME/bin:$PATH",
                    "echo \"Java version installed:\"",
                    "java -version",
                    "echo \"[INFO] install_java completed in $SECONDS s at $(date -u +%Y-%m-%dT%H:%M:%SZ)\""
                  ]
                }
              },
              {
                name   = "install_netacuity"
                action = "ExecuteBash"
                inputs = {
                  commands = [
                    "SECONDS=0",
                    "echo \"[INFO] install_netacuity started at $(date -u +%Y-%m-%dT%H:%M:%SZ)\"",
                    "NA_VERS=7.0.1.1",
                    "TMP_DIR=/apps/digitalenvoy",
                    "mkdir -p $TMP_DIR",
                    "echo S3 bucket selected ${local.ami_docs_bucket}",
                    "echo \"[INFO] Downloading installer properties from S3\"",
                    "aws s3 cp s3://${local.ami_docs_bucket}/digitalenvoy/netacuity.properties installer.properties",
                    "echo \"[INFO] Downloading NetAcuity zip from S3\"",
                    "aws s3 cp s3://${local.ami_docs_bucket}/digitalenvoy/netacuity-server-installer-dist-7.0.1.1.zip .",
                    "echo \"Unpacking NA Server...\"",
                    "unzip netacuity-server-installer-dist-$NA_VERS.zip -d $TMP_DIR-na-installer-$NA_VERS",
                    "cp installer.properties $TMP_DIR-na-installer-$NA_VERS/installer.properties",
                    "echo \"Creating installation directory...\"",
                    "mkdir -p /apps/server/NetAcuity",
                    "chown -R siadmin:sysint /apps/server/NetAcuity",
                    "echo \"Installing NA Server $NA_VERS...\"",
                    "cd $TMP_DIR-na-installer-$NA_VERS && ls -lrt && ./linux_netacuity_installer.sh --silent -c installer.properties -d /apps/server/NetAcuity/server",
                    "echo \"Setup systemctl...\"",
                    "sh /apps/server/NetAcuity/server/scripts/linux64/linux-root-actions.sh /apps/server/NetAcuity/server siadmin",
                    "echo \"[INFO] install_netacuity completed in $SECONDS s at $(date -u +%Y-%m-%dT%H:%M:%SZ)\"",
                  ]
                }
              }
            ]
          }
        ]
      })
    }
  ]
}
