# move AWS Backup Region Settings to count
moved {
  from = aws_backup_region_settings.this
  to   = aws_backup_region_settings.this[0]
}
