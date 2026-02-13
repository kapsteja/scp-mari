variable "scp_files" {
  description = "List of SCP JSON files to deploy"
  type        = list(string)
}

variable "attachments" {
  description = "Map of SCP name to list of target IDs (OUs or accounts)"
  type        = map(list(string))
  default     = {}
}
 variable "policy_tags" {
  description = "Tags to apply to all scp policies"
  type = map(string)
  default = {}
 }