# Create SCPs
resource "aws_organizations_policy" "scp" {
  for_each = data.local_file.scp

  name        = replace(each.key, ".json", "")
  description = "Managed SCP: ${each.key}"
  lifecycle {
    ignore_changes = [description, name,tags,tags_all]
  }
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content
  tags = var.policy_tags
}

# Build a flat map of attachments so each attachment has its own instance key
locals {
  attachments_flat = {
    for pair in flatten([for p, tlist in var.attachments : [for t in tlist : { key = "${p}_${t}" , policy_file = "${p}.json", target = t } ]]) : pair.key => pair
  }
}

# Attach SCPs to OUs or Accounts (one resource per policy-target pair)
resource "aws_organizations_policy_attachment" "attach" {
  for_each = local.attachments_flat

  policy_id = aws_organizations_policy.scp[each.value.policy_file].id
  target_id = each.value.target
}