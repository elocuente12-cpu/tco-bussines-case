# test region
provider "aws" {
  region = var.region
}

data "aws_iam_session_context" "this" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "PolicyForSecretOwners"
    actions = [
      "secretsmanager:CancelRotateSecret",
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteResourcePolicy",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:ListSecrets",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RemoveRegionsFromReplication",
      "secretsmanager:ReplicateSecretToRegions",
      "secretsmanager:RestoreSecret",
      "secretsmanager:RotateSecret",
      "secretsmanager:StopReplicationToReplica",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:ValidateResourcePolicy",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.this.issuer_arn]
    }
  }
}

data "aws_caller_identity" "current" {}

# create kms key
module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  description = "KMS key for testing Secret Manager module"
  key_owners  = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole"]

  tags = var.tags
}

# example policy to be used to managed secrets 
module "secret" {
  source = "../../."

  # it is recommended to use secure methods of passing this argument
  # for example jenkins credentials
  secret_string = "super secret string, dont do it in plain text like this"

  # increment secret_string_version to trigger a secret update without re-creating the resource
  secret_string_version = 1

  name            = "eits-tf-aws-secrets-manager"
  description     = "Test for Secret Manager module"
  kms_key_id      = module.kms_key.key_id
  policy_override = data.aws_iam_policy_document.this.json
  tags            = var.tags
}

# Note: external_secret_rotation_role_arn and external_secret_rotation_metadata require
# type = "AWS_MANAGED_ROTATION" which needs AWS account enrollment - test manually in enrolled accounts.