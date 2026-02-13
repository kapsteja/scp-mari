#!/bin/bash
set -e

echo "=== Generating Terraform import commands (imports.sh), attachments map (terraform.tfvars), and exporting SCP JSONs into /policies ==="

# Output filesr
IMPORTS_FILE="imports.sh"
TFVARS_FILE="terraform.tfvars"
POLICIES_DIR="policies"

# Reset files
echo "#!/bin/bash" > "$IMPORTS_FILE"
echo "set -euo pipefail" >> "$IMPORTS_FILE"
echo "# Auto-generated Terraform import commands" >> "$IMPORTS_FILE"
echo "" >> "$IMPORTS_FILE"

echo "# Auto-generated variables" > "$TFVARS_FILE"
echo "scp_files = [" >> "$TFVARS_FILE"

# Temp file to collect attachments entries while we build scp_files
ATTACH_TMP="${TFVARS_FILE}.attachments.tmp"
> "$ATTACH_TMP"

# Ensure policies directory exists
mkdir -p "$POLICIES_DIR"

# Step 1: List all SCPs
policies=$(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[*].Id' --output text | tr -d '\r')

for pid in $policies; do
  # Get SCP name and sanitize it for filenames
  raw_name=$(aws organizations describe-policy --policy-id "$pid" \
    --query 'Policy.PolicySummary.Name' --output text | tr -d '\r')

  # Detect if the policy is AWS-managed; skip those (cannot be imported)
  aws_managed_raw=$(aws organizations describe-policy --policy-id "$pid" \
    --query 'Policy.AwsManaged' --output text 2>/dev/null || true)
  aws_managed=$(echo "${aws_managed_raw}" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
  if [ "${aws_managed}" = "true" ] || [ "${aws_managed}" = "yes" ] || [ "${aws_managed}" = "1" ]; then
    echo ">>> Skipping AWS-managed policy: $raw_name (id: $pid) — cannot import into Terraform"
    continue
  fi
  # Fallback: some AWS-managed policies may not populate AwsManaged consistently; skip common AWS-managed names
  if echo "$raw_name" | tr '[:upper:]' '[:lower:]' | grep -Eiq 'fullawsaccess|aws-managed|aws managed'; then
    echo ">>> Skipping likely-AWS-managed policy by name: $raw_name (id: $pid)"
    continue
  fi

  safe_name=$(echo "$raw_name" | tr -d '[:space:]' | tr '/:' '_' | tr -cd '[:alnum:]_-')

  echo ">>> Processing SCP: $raw_name (safe filename: $safe_name.json)"

  # SCP import command (quoted correctly)
  echo "terraform import 'aws_organizations_policy.scp[\"${safe_name}.json\"]' $pid" >> "$IMPORTS_FILE"

  # Add this SCP filename to scp_files list for terraform (prevents interactive prompts)
  echo "  \"${safe_name}.json\"," >> "$TFVARS_FILE"

  # Export SCP JSON into /policies/<safe_name>.json
  aws organizations describe-policy --policy-id "$pid" \
    --query 'Policy.Content' --output text > "${POLICIES_DIR}/${safe_name}.json"

  # Step 2: List attachments for each SCP using jq for clean parsing
  targets=$(aws organizations list-targets-for-policy --policy-id "$pid" \
    --output json | jq -r '.Targets[].TargetId' | tr -d '\r')

  echo ">>> Attachments for $safe_name: [$targets]"

  echo "  \"${safe_name}\" = [" >> "$ATTACH_TMP"
  if [ -n "$targets" ]; then
    for tid in $targets; do
      tid_clean=$(echo "$tid" | tr -d '\r')
      # Attachment import command (quoted correctly)
      echo "terraform import 'aws_organizations_policy_attachment.attach[\"${safe_name}_${tid_clean}\"]' ${tid_clean}:${pid}" >> "$IMPORTS_FILE"
      echo "    \"${tid_clean}\"," >> "$ATTACH_TMP"
    done
  else
    echo "    # No attachments found" >> "$ATTACH_TMP"
  fi
  echo "  ]" >> "$ATTACH_TMP"
done

# Close scp_files array
echo "]" >> "$TFVARS_FILE"

# Append attachments map collected in temp file
echo "" >> "$TFVARS_FILE"
echo "# Auto-generated attachments map" >> "$TFVARS_FILE"
echo "attachments = {" >> "$TFVARS_FILE"
cat "$ATTACH_TMP" >> "$TFVARS_FILE"
echo "}" >> "$TFVARS_FILE"
rm -f "$ATTACH_TMP"

# Make the imports script executable
chmod +x "$IMPORTS_FILE" || true

echo "=== Done! ==="
echo "1. Run 'bash imports.sh' to import everything into Terraform state."
echo "2. Check 'terraform.tfvars' for your attachments map."
echo "3. All SCP JSONs are now exported into ./policies/"