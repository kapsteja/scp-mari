#!/usr/bin/env bash
set -euo pipefail
echo "=== Generating imports.sh, terraform.tfvars, and exporting SCP JSONs into ./policies (excluding guardrails) ==="
IMPORTS_FILE="imports.sh"
TFVARS_FILE="terraform.tfvars"
POLICIES_DIR="policies"
ATTACH_TMP="${TFVARS_FILE}.attachments.tmp"
# --- Hard reset outputs (prevents leftover files) ---
rm -f "$IMPORTS_FILE" "$TFVARS_FILE" "$ATTACH_TMP"
rm -rf "$POLICIES_DIR"
mkdir -p "$POLICIES_DIR"
# --- Create imports.sh header ---
{
 echo "#!/usr/bin/env bash"
 echo "set -euo pipefail"
 echo "# Auto-generated Terraform import commands"
 echo ""
} > "$IMPORTS_FILE"
# --- Start tfvars ---
{
 echo "# Auto-generated variables"
 echo "scp_files = ["
} > "$TFVARS_FILE"
: > "$ATTACH_TMP"
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
# Normalize strings so matching can't be bypassed by unicode dashes / hidden chars
norm_lc() {
 # 1) remove CR
 # 2) replace common unicode dashes with "-"
 # 3) keep printable chars
 # 4) lowercase + trim
 printf '%s' "$1" \
   | tr -d '\r' \
   | sed 's/[–—-]/-/g' \
   | tr -cd '[:print:]' \
   | tr '[:upper:]' '[:lower:]' \
   | trim
}
POLICY_IDS="$(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
 --query 'Policies[*].Id' --output text | tr -d '\r' || true)"
if [[ -z "${POLICY_IDS}" ]]; then
 echo "No SCP policies returned by AWS Organizations. Exiting."
 exit 0
fi
for PID in $POLICY_IDS; do
 RAW_NAME="$(aws organizations describe-policy --policy-id "$PID" \
   --query 'Policy.PolicySummary.Name' --output text 2>/dev/null | trim || true)"
 RAW_DESC="$(aws organizations describe-policy --policy-id "$PID" \
   --query 'Policy.PolicySummary.Description' --output text 2>/dev/null | trim || true)"
 NAME_LC="$(norm_lc "$RAW_NAME")"
 DESC_LC="$(norm_lc "$RAW_DESC")"
 AWS_MANAGED_RAW="$(aws organizations describe-policy --policy-id "$PID" \
   --query 'Policy.AwsManaged' --output text 2>/dev/null | trim || true)"
 AWS_MANAGED_LC="$(norm_lc "$AWS_MANAGED_RAW")"
 echo "DEBUG: PID=$PID name=[$NAME_LC] aws_managed=[$AWS_MANAGED_LC]"
 # --- Skip AWS managed ---
 if [[ "$AWS_MANAGED_LC" == "true" || "$AWS_MANAGED_LC" == "yes" || "$AWS_MANAGED_LC" == "1" ]]; then
   echo ">>> SKIP AWS-managed: $RAW_NAME ($PID)"
   continue
 fi
 # --- Skip Guardrails / Control Tower (name OR description) ---
 # This catches:
 # - aws-guardrails-*
 # - anything containing guardrail/guardrails
 # - control tower / awscontroltower / aws-control-tower
 # - "Guardrails applied ..." descriptions
 if echo "${NAME_LC} ${DESC_LC}" | grep -Eqi \
   'aws-guardrails|guardrail|guardrails|control[[:space:]-]*tower|awscontroltower|aws[[:space:]-]*control[[:space:]-]*tower'; then
   echo ">>> SKIP Guardrails/ControlTower: $RAW_NAME ($PID)"
   continue
 fi
 SAFE_NAME="$(printf '%s' "$RAW_NAME" \
   | tr -d '\r' \
   | sed 's/[–—-]/-/g' \
   | tr '/:' '_' \
   | tr -d '"' \
   | tr -s ' ' '_' \
   | tr -cd '[:alnum:]_.-')"
 if [[ -z "$SAFE_NAME" ]]; then
   echo ">>> WARN: could not create safe name for [$RAW_NAME]. Skipping."
   continue
 fi
 echo ">>> PROCESS: $RAW_NAME  ->  ${SAFE_NAME}.json"
 echo "terraform import 'aws_organizations_policy.scp[\"${SAFE_NAME}.json\"]' ${PID}" >> "$IMPORTS_FILE"
 echo "  \"${SAFE_NAME}.json\"," >> "$TFVARS_FILE"
 aws organizations describe-policy --policy-id "$PID" \
   --query 'Policy.Content' --output text > "${POLICIES_DIR}/${SAFE_NAME}.json"
 TARGETS="$(aws organizations list-targets-for-policy --policy-id "$PID" --output json \
   | jq -r '.Targets[].TargetId' 2>/dev/null | tr -d '\r' || true)"
 {
   echo "  \"${SAFE_NAME}\" = ["
   if [[ -n "${TARGETS}" ]]; then
     for TID in $TARGETS; do
       TID_CLEAN="$(printf '%s' "$TID" | tr -d '\r' | trim)"
       echo "terraform import 'aws_organizations_policy_attachment.attach[\"${SAFE_NAME}_${TID_CLEAN}\"]' ${TID_CLEAN}:${PID}" >> "$IMPORTS_FILE"
       echo "    \"${TID_CLEAN}\","
     done
   else
     echo "    # No attachments found"
   fi
   echo "  ]"
 } >> "$ATTACH_TMP"
done
echo "]" >> "$TFVARS_FILE"
{
 echo ""
 echo "# Auto-generated attachments map"
 echo "attachments = {"
 cat "$ATTACH_TMP"
 echo "}"
} >> "$TFVARS_FILE"
rm -f "$ATTACH_TMP"
chmod +x "$IMPORTS_FILE" || true
echo "=== Done ==="
echo "Generated:"
echo " - $IMPORTS_FILE"
echo " - $TFVARS_FILE"
echo " - ./$POLICIES_DIR/*.json"
echo ""
echo "Next:"
echo "  1) bash ./imports.sh"
echo "  2) terraform plan -var-file=conf/terraform.tfvars"