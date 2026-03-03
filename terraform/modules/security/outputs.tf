output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket name"
  value       = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "iam_instance_profile" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.cloudwatch_logs.name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "codedeploy_role_arn" {
  description = "CodeDeploy service role ARN"
  value       = aws_iam_role.codedeploy.arn
}

output "jenkins_instance_profile" {
  description = "Jenkins IAM instance profile name"
  value       = aws_iam_instance_profile.jenkins.name
}
