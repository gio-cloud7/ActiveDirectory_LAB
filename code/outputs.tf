output "dc1_public_ip" {
  description = "Public IP address of the first Domain Controller"
  value       = aws_instance.dc1.public_ip
}

output "dc2_public_ip" {
  description = "Public IP address of the second Domain Controller"
  value       = aws_instance.dc2.public_ip
}

output "app_server_public_ip" {
  description = "Public IP address of the Application Server"
  value       = aws_instance.app_server.public_ip
}

output "sql_server_public_ip" {
  description = "Public IP address of the SQL Server"
  value       = aws_instance.sql_server.public_ip
}

output "workstations_public_ips" {
  description = "Public IP addresses of the Workstations"
  value       = aws_instance.workstations[*].public_ip
}

output "domain_name" {
  description = "Active Directory domain name"
  value       = var.ad_domain_name
}
