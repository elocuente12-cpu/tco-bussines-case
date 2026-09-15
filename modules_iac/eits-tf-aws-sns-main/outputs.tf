output "topic_id" {
  value       = aws_sns_topic.this.id
  description = "SNS topic ID"
}

output "topic_name" {
  value       = aws_sns_topic.this.name
  description = "SNS topic name"
}

output "topic_arn" {
  value       = aws_sns_topic.this.arn
  description = "SNS topic ARN"
}

output "beginning_archive_time" {
  value       = aws_sns_topic.this.beginning_archive_time
  description = "The oldest timestamp at which a FIFO topic subscriber can start a replay"
}

output "topic_owner" {
  value       = aws_sns_topic.this.owner
  description = "SNS topic owner"
}

output "topic_subscriptions" {
  value       = aws_sns_topic_subscription.this
  description = "SNS topic subscriptions"
}
