output "scp_ids" {
  value = { for k, v in aws_organizations_policy.scp : k => v.id }
}

output "scp_names" {
  value = [for k, v in aws_organizations_policy.scp : v.name]
}