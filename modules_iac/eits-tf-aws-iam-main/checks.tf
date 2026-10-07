locals {
  # This is all for IAM-057
  # Convert the json once so we don't have to call that each time
  trust_policy = jsondecode(data.aws_iam_policy_document.assume_role_policy.json)

  # Get all the statements with AWS principals
  aws_principal_statements = [
    for statement in local.trust_policy.Statement : statement
    if try(statement.Principal.AWS, null) != null
  ]

  # Extract all the ARNs to a list
  aws_principal_arns = flatten([
    for statement in local.aws_principal_statements :
    try(tolist([statement.Principal.AWS]), [])
  ])

  # Extract the account ID's from the ARNs
  aws_principals = distinct([
    for arn in local.aws_principal_arns :
    can(regex("^arn:aws:iam::([0-9]+):.*$", arn)) ?
    tonumber(replace(arn, "/^arn:aws:iam::([0-9]+):.*$/", "$1")) :
    null
  ])

  # Check the AWS principals to see if they are any from external accounts.
  has_external_principals = length([
    for account_id in local.aws_principals :
    account_id if account_id != null && account_id != data.aws_caller_identity.current.account_id
  ]) > 0

  # Check if we have an external ID condition
  has_external_id = length([
    for statement in local.trust_policy.Statement :
    true if try(statement.Condition.StringEquals["sts:ExternalId"], null) != null
  ]) > 0

  # Check if we have multifactor
  has_mfa_condition = length([
    for statement in local.trust_policy.Statement :
    true if try(statement.Condition.StringEquals["aws:MultiFactorAuthPresent"], null) == "true"
  ]) > 0

  statements = flatten([
    for policy in var.policy_documents : [
      for statement in jsondecode(policy).Statement : statement
    ]
  ])


  # Map of non-recommended combination of actions for wildcard resources.
  non_recommended_wildcard_actions = {
    "iam055" : [
      "iam:GetAccountAuthorizationDetails",
    ],
    "iam055-2" : [
      "iam:Get*",
    ],
    "iam107" : [
      "iam:PutGroupPolicy",
    ],
    "iam108" : [
      "ec2:RunInstances",
      "iam:PassRole"
    ],
    "iam109" : [
      "iam:AttachGroupPolicy",
    ],
    "iam110" : [
      "iam:AddUserToGroup",
    ],
    "iam111" : [
      "iam:SetDefaultPolicyVersion",
    ],
    "iam112" : [
      "iam:CreatePolicyVersion",
    ],
    "iam113" : [
      "iam:PutRolePolicy",
    ],
    "iam114" : [
      "iam:AttachUserPolicy",
    ],
    "iam115" : [
      "iam:CreateLoginProfile",
    ],
    "iam116" : [
      "cloudformation:CreateStack",
      "iam:PassRole"
    ],
    "iam117" : [
      "iam:CreateAccessKey",
    ],
    "iam118" : [
      "iam:UpdateLoginProfile",
    ],
    "iam119" : [
      "sts:AssumeRole",
      "iam:UpdateAssumeRolePolicy"
    ],
    "iam120" : [
      "iam:PutUserPolicy",
    ],
    "iam121" : [
      "glue:CreateDevEndpoint",
      "iam:PassRole"
    ],
    "iam122" : [
      "iam:AttachRolePolicy",
    ],
    "iam123" : [
      "lambda:CreateFunction",
      "lambda:InvokeFunction",
      "iam:PassRole"
    ],
    "iam124" : [
      "lambda:UpdateFunctionCode",
    ],
    "iam125" : [
      "glue:UpdateDevEndpoint"
    ],
    "iam152" : [
      "datapipeline:CreatePipeline",
      "datapipeline:PutPipelineDefinition",
      "iam:PassRole"
    ]
  }

}

# IAM-057
check "privilege_escalation_warning_cross_account" {
  assert {
    condition = (
      !local.has_external_principals ||                                                     # Either has no external principals
      (local.has_external_principals && (local.has_external_id || local.has_mfa_condition)) # or it is external principals but it has external id OR mfa enabled.
    )
    error_message = <<EOT
Wiz Rule IAM-057:
IAM assumed role cross account should have an external ID or MFA
The primary function of this rule is to address the confused deputy problem. In abstract terms, the external ID allows the user that is assuming the role to assert the circumstances under which they are operating. It also allows the account owner to permit the role to be assumed only under specific circumstances.
EOT
  }
}

# Check for non-recommended wildcard combination of actions
# IAM-055, IAM-085, IAM-107, IAM-108, IAM-109, IAM-110, IAM-111, IAM-112,
# IAM-113, IAM-114, IAM-115, IAM-116, IAM-117, IAM-118, IAM-119, IAM-120,
# IAM-121, IAM-122, IAM-123, IAM-124, IAM-125, IAM-152, IAM-185, IAM-213
check "privilege_escalation_warning_combinations" {
  assert {
    condition = alltrue(flatten([
      for statement in local.statements :
      !(statement.Effect == "Allow" &&
        (try(statement.Resource == "*", false) || try(contains(tolist(statement.Resource),
        "*"), false)) &&
        anytrue([
          for actions in local.non_recommended_wildcard_actions :
          alltrue([
            anytrue([
              for actions in local.non_recommended_wildcard_actions :
              alltrue([
                anytrue([
                  for action in try(tolist(statement.Action), [statement.Action], []) :
                  contains(actions, action)
                ])
              ])
            ])
          ])
        ])
      )
    ]))
    error_message = <<EOT
One or more of the policies supplied contain a wildcard (*) Resource with a combinations of Actions that are not recommended. This is potentially a security risk. For more details run a Wiz.io IaC scan on this plan.
EOT
  }
}

# IAM-146
check "privilege_escalation_warning_iam146" {
  assert {
    condition = alltrue(flatten([
      for statement in local.trust_policy.Statement :
      try(statement.Principal, null) == null ? true : !alltrue([
        for principal_type, identifiers in statement.Principal :
        statement.Effect == "Allow" && alltrue([
          for identifier in try(tolist(identifiers), [identifiers]) :
          (identifier == "*" ||
            identifier == format("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id) ||
            identifier == format("%s", data.aws_caller_identity.current.account_id) ||
            endswith(identifier, ":root")
          )
        ])
      ])
    ]))
    error_message = <<EOT
Wiz Rule IAM-146:
IAM Role should not allow all principals to assume
If you reference`:root`in a role's trust policy, you might allow more principals to assume your role than you intended as it equates to the principals in the account, not the root user of that account.
It is bad practice to allow roles to assume a root account or all accounts (*), even with conditions.
It is recommended to follow the principle of least privilege (PoLP) by restricting the IAM Role Trust Policy to use the Principal element to only allow specific principals or paths to assume the role.
EOT
  }
}

# IAM-182
check "privilege_escalation_warning_iam182" {
  assert {
    condition = alltrue(flatten([
      for statement in local.statements :
      !(try(statement.NotAction != null, false) ||
        try(statement.NotResource != null, false) ||
        try(contains([for k, v in try(statement.Principal, {}) : k], "NotPrincipal"), false)
      )
    ]))
    error_message = <<EOT
Wiz Rule IAM-182:
IAM policy should not use the NotAction, NotPrincipal, or NotResource elements
This rule does not take into account the effect or condition elements, as in any case, it is not recommended to use these elements.
These policy elements explicitly match everything except the specified values. This, in turn, means that all of the applicable actions, principals, or resources that are not listed are allowed - if you use the Allow effect.
Using these statement elements can result in a shorter policy by listing only a few values that should not match, but inappropriate use can make the policy too permissive, leading eventually to unauthorized access.
It is recommended to follow the principle of least privilege and use the Action, Principal, and Resource elements instead.
EOT
  }
}

# IAM-197
check "all_actions_on_any_service_check_iam197" {
  assert {
    condition = alltrue(flatten([
      for statement in local.statements :
      !(statement.Effect == "Allow" &&
        anytrue([
          for action in try(tolist(statement.Action), [statement.Action], []) :
          endswith(action, ":*") || action == "*"
        ]) &&
        try(statement.Condition, null) == null
      )
    ]))
    error_message = <<EOT
Wiz Rule IAM-197:
IAM policy should not allow all actions on any service. This occurs when all of the following conditions are met:
- The Effect is "Allow".
- The Action ends with ":*", allowing all actions on a service.
- The Condition is null or does not exist.
It is recommended to restrict IAM policies to only the required actions and include appropriate conditions to follow the principle of least privilege.
EOT
  }
}