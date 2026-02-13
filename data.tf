# Load SCP JSON files
data "local_file" "scp" {
  for_each = toset(var.scp_files)
  filename = "${path.module}/policies/${each.value}"
}