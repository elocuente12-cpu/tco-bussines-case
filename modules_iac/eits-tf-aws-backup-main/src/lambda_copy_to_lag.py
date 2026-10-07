### ADAPTED FROM FUNCTION PROVIDED BY AWS ###
import os
import json
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

BACKUP_ROLE_ARN = os.environ.get("BACKUP_ROLE_ARN")
DESTINATION_VAULT_ARN = os.environ.get("DESTINATION_VAULT_ARN")
RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "7"))
TRANSIENT_ERROR_CODES = ["ThrottlingException", "ServiceUnavailableException", "InternalServerError"]

def get_vault_name_from_arn(arn):
    # Extract vault name from ARN: arn:aws:backup:region:account:backup-vault:vault-name
    return arn.split(":")[-1] if arn else "unknown"

def lambda_handler(event, context):
    logger.info("Lambda handler invoked with event: %s", event)
    recovery_point_arn = None
    
    try:
        event_data = extract_event_data(event)
        recovery_point_arn = event_data["recovery_point_arn"]
        source_vault_name = event_data["source_vault_name"]
        
        logger.info("Extracted - recovery_point_arn: %s, source_vault_name: %s", recovery_point_arn, source_vault_name)
        
        is_valid, error_message = validate_recovery_point_arn(recovery_point_arn)
        if not is_valid:
            logger.error("Invalid recovery point ARN - arn: %s, error: %s", recovery_point_arn, error_message)
            return build_response(400, "error", None, recovery_point_arn, f"Invalid recovery point ARN: {error_message}")
        
        backup_client = boto3.client("backup")
        if check_existing_in_destination_vault(recovery_point_arn, backup_client):
            logger.info("Recovery point already exists in destination vault, skipping - arn: %s", recovery_point_arn)
            return build_response(200, "skipped", None, recovery_point_arn, f"Recovery point already exists in {get_vault_name_from_arn(DESTINATION_VAULT_ARN)}")
        
        # Added - Get retention days from the recovery point's lifecycle, defaulting to specified RETENTION_DAYS if not found
        recovery_point_retention_days = get_recovery_point_retention_days(recovery_point_arn, source_vault_name, backup_client)
        
        copy_result = initiate_copy_job(recovery_point_arn, source_vault_name, backup_client, recovery_point_retention_days)
        logger.info("Copy job initiated - copy_job_id: %s, destination: %s", copy_result["copy_job_id"], DESTINATION_VAULT_ARN)
        
        return build_response(200, "success", copy_result["copy_job_id"], recovery_point_arn, "Copy job initiated successfully")
        
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_message = e.response.get("Error", {}).get("Message", "Unknown error")
        logger.error("AWS API error - code: %s, message: %s, arn: %s", error_code, error_message, recovery_point_arn)
        
        if error_code in TRANSIENT_ERROR_CODES:
            logger.info("Transient error, re-raising for retry")
            raise
        
        return build_response(500, "error", None, recovery_point_arn, f"AWS API error: {error_code} - {error_message}")
        
    except Exception as e:
        logger.error("Unexpected error: %s", str(e), exc_info=True)
        return build_response(500, "error", None, recovery_point_arn, f"Error: {str(e)}")

def extract_event_data(event):
    if not event or not isinstance(event, dict):
        raise ValueError("Event must be a non-empty dictionary")
    detail = event.get("detail")
    if not detail or not isinstance(detail, dict):
        raise ValueError("Event must contain 'detail' field")
    recovery_point_arn = detail.get("destinationRecoveryPointArn")
    if not recovery_point_arn:
        raise ValueError("Event detail must contain 'destinationRecoveryPointArn'")
    dest_vault_arn = detail.get("destinationBackupVaultArn", "")
    source_vault_name = dest_vault_arn.split(":")[-1] if dest_vault_arn else "unknown"
    return {"recovery_point_arn": recovery_point_arn, "source_vault_name": source_vault_name, "source_vault_arn": dest_vault_arn}

def validate_recovery_point_arn(arn):
    if not arn or not isinstance(arn, str):
        return False, "ARN must be a non-empty string"
    if not arn.strip():
        return False, "ARN cannot be empty or whitespace"
    if not arn.startswith("arn:aws:"):
        return False, "ARN does not match expected format"
    return True, None

# Added function to get retention days from the recovery point's lifecycle, defaulting to RETENTION_DAYS if not found
def get_recovery_point_retention_days(recovery_point_arn, source_vault_name, backup_client):
    logger.info(f"Getting retention days for recovery point: {recovery_point_arn} in Vault {source_vault_name}...")
    recovery_point = backup_client.describe_recovery_point(BackupVaultName=source_vault_name, RecoveryPointArn=recovery_point_arn)
    lifecycle = recovery_point.get("Lifecycle", {})
    delete_after_days = lifecycle.get("DeleteAfterDays")
    if delete_after_days is not None:
        logger.info(f"Recovery point retention days: {delete_after_days}")
        return delete_after_days
    else:
        logger.info(f"Recovery point retention days not found, defaulting to {RETENTION_DAYS}")
        return RETENTION_DAYS

def check_existing_in_destination_vault(recovery_point_arn, backup_client):
    try:
        vault_name = get_vault_name_from_arn(DESTINATION_VAULT_ARN)
        response = backup_client.list_recovery_points_by_backup_vault(BackupVaultName=vault_name, MaxResults=1000)
        existing_arns = [rp.get("RecoveryPointArn", "") for rp in response.get("RecoveryPoints", [])]
        rp_id = recovery_point_arn.split(":")[-1]
        return any(rp_id in arn for arn in existing_arns)
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "ResourceNotFoundException":
            return False
        if error_code == "AccessDeniedException":
            logger.warning("Cannot check idempotency for cross-account vault (AccessDenied), proceeding with copy")
            return False
        raise

def initiate_copy_job(recovery_point_arn, source_vault_name, backup_client, recovery_point_retention_days):
    logger.info(f"Copy job initiated. Recovery point ARN: {recovery_point_arn}; Destination vault ARN: {DESTINATION_VAULT_ARN}; Retention days: {recovery_point_retention_days}")
    response = backup_client.start_copy_job(
        RecoveryPointArn=recovery_point_arn,
        SourceBackupVaultName=source_vault_name,
        DestinationBackupVaultArn=DESTINATION_VAULT_ARN,
        IamRoleArn=BACKUP_ROLE_ARN,
        Lifecycle={"DeleteAfterDays": recovery_point_retention_days}
    )
    return {"copy_job_id": response.get("CopyJobId"), "destination_vault_arn": DESTINATION_VAULT_ARN}

def build_response(status_code, status, copy_job_id, recovery_point_arn, message):
    return {"statusCode": status_code, "body": {"status": status, "copyJobId": copy_job_id, "recoveryPointArn": recovery_point_arn, "message": message}}
