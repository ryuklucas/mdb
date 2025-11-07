#!/bin/zsh
# --- User Input ---
# Prompt for the Organization ID
echo "Please enter your MongoDB Atlas Organization ID:"
read ORGANIZATION_ID

# Validate that an ID was provided
if [[ -z "$ORGANIZATION_ID" ]]; then
    echo "Error: Organization ID cannot be empty. Exiting."
    exit 1
fi

echo $'\n'"Starting Atlas TLS Protocol Audit for Organization: ${ORGANIZATION_ID}"
echo "----------------------------------------------------------------------"

# --- Functions ---

# Function to generate the cluster link
generate_cluster_link() {
    local project_id=$1
    local cluster_name=$2
    # The Atlas base URL structure is always: cloud.mongodb.com/v2/{projectId}#clusters/detail/{clusterName}
    echo "https://cloud.mongodb.com/v2/${project_id}#clusters/detail/${cluster_name}"
}

# --- Main Script ---

# Initialize Markdown table header
REPORT_TABLE="| Cluster | minimumEnabledTlsProtocol |"
REPORT_TABLE+=$'\n'"| :--- | :---: |"

# 1. Loop through all projects in the organization
# Uses JSON output and 'jq' to extract project IDs and names
atlas projects list --orgId "${ORGANIZATION_ID}" --output json 2>/dev/null | \
jq -r '.results[] | "\(.id) \(.name)"' | \
while read -r PROJECT_ID PROJECT_NAME; do
    
    echo $'\n'"-> Processing Project: ${PROJECT_NAME} (${PROJECT_ID})"
    
    # 2. Loop through all clusters in the current project
    # Uses JSON output and 'jq' to extract cluster names
    atlas clusters list --projectId "${PROJECT_ID}" --output json 2>/dev/null | \
    jq -r '.results[] | .name' | \
    while read -r CLUSTER_NAME; do
        
        echo "   -> Retrieving settings for Cluster: ${CLUSTER_NAME}"
        
        # 3. Retrieve the minimumEnabledTlsProtocol setting
        # Use atlas clusters advancedSettings describe and jq to get the TLS value
        # '2>/dev/null' suppresses non-fatal errors (e.g., if a cluster tier doesn't support advanced settings)
        TLS_PROTOCOL=$(atlas clusters advancedSettings describe "${CLUSTER_NAME}" \
                       --projectId "${PROJECT_ID}" \
                       --output json 2>/dev/null | \
                       jq -r '.minimumEnabledTlsProtocol')

        # Check if the TLS protocol was found/valid
        if [[ -z "${TLS_PROTOCOL}" ]] || [[ "${TLS_PROTOCOL}" == "null" ]]; then
            # Set a helpful default message for clusters that don't expose this field (e.g., M0/M2/M5)
            # Atlas enforces a minimum of TLS 1.2 for all modern clusters.
            TLS_PROTOCOL="N/A (Atlas default is TLS1_2 or higher)"
        fi

        # 4. Generate the cluster URL and link
        CLUSTER_URL=$(generate_cluster_link "${PROJECT_ID}" "${CLUSTER_NAME}")
        CLUSTER_LINK="[${CLUSTER_NAME}](${CLUSTER_URL})"

        # 5. Append row to the report table
        REPORT_TABLE+=$'\n'"| ${CLUSTER_LINK} | ${TLS_PROTOCOL} |"

    done
done

echo $'\n\n'
echo "### 🔒 MongoDB Atlas TLS Protocol Audit Report"
echo "Organization ID: ${ORGANIZATION_ID}"
echo "---"
# Print the final Markdown table
echo "${REPORT_TABLE}"

# End of script
