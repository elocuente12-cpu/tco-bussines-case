### PROVIDED BY AWS ###
import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

INTERMEDIATE_VAULT_NAME = os.environ.get("INTERMEDIATE_VAULT_NAME")
TRANSIENT_ERROR_CODES = ["ThrottlingException", "ServiceUnavailableException", "InternalServerError"]

def lambda_handler(event, context):
    logger.info("Cleanup Lambda invoked with event: %s", event)
    
    try:
        detail = event.get("detail", {})
        # Source recovery point ARN is in the resources array
        resources = event.get("resources", [])
        source_recovery_point_arn = resources[0] if resources else None
        source_vault_arn = detail.get("sourceBackupVaultArn", "")
        source_vault_name = source_vault_arn.split(":")[-1] if source_vault_arn else ""
        
        if not source_recovery_point_arn:
            logger.error("No source recovery point ARN in event resources")
            return {"statusCode": 400, "body": "Missing source recovery point ARN"}
        
        # Only delete if source was the intermediate vault
        if source_vault_name != INTERMEDIATE_VAULT_NAME:
            logger.info("Source vault %s is not intermediate vault %s, skipping cleanup", source_vault_name, INTERMEDIATE_VAULT_NAME)
            return {"statusCode": 200, "body": "Skipped - not from intermediate vault"}
        
        backup_client = boto3.client("backup")
        
        logger.info("Deleting recovery point from intermediate vault - arn: %s, vault: %s", source_recovery_point_arn, INTERMEDIATE_VAULT_NAME)
        backup_client.delete_recovery_point(
            BackupVaultName=INTERMEDIATE_VAULT_NAME,
            RecoveryPointArn=source_recovery_point_arn
        )
        
        logger.info("Successfully deleted recovery point from intermediate vault")
        return {"statusCode": 200, "body": f"Deleted {source_recovery_point_arn} from {INTERMEDIATE_VAULT_NAME}"}
        
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_message = e.response.get("Error", {}).get("Message", "Unknown error")
        logger.error("AWS API error - code: %s, message: %s", error_code, error_message)
        
        if error_code == "ResourceNotFoundException":
            logger.info("Recovery point already deleted or not found")
            return {"statusCode": 200, "body": "Recovery point not found (already deleted)"}
        
        if error_code in TRANSIENT_ERROR_CODES:
            raise
        
        return {"statusCode": 500, "body": f"Error: {error_code} - {error_message}"}
        
    except Exception as e:
        logger.error("Unexpected error: %s", str(e), exc_info=True)
        return {"statusCode": 500, "body": f"Error: {str(e)}"}
