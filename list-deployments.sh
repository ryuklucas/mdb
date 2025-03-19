#!/bin/bash

# Check if orgId is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <orgId>"
    exit 1
fi

ORG_ID=$1

# Print header
echo "| Project ID                      | Project Name           | Deployment Name      | State    | MongoDB Version |"
echo "|---------------------------------|------------------------|---------------------|----------|----------------|"

# List all projects for the given orgId
project_list=$(atlas projects list --orgId "$ORG_ID")
if [ $? -ne 0 ]; then
    echo "Failed to list projects for orgId: $ORG_ID"
    exit 1
fi

# Skip the header line and iterate through each line
IFS=$'\n'
echo "$project_list" | sed 1d | while read -r project; do
    projectId=$(echo "$project" | awk '{print $1}' | xargs)
    projectName=$(echo "$project" | awk '{print $2}' | xargs)

    # List all clusters for the current projectId
    cluster_list=$(atlas clusters list --projectId "$projectId")
    if [ $? -ne 0 ]; then
        echo "Failed to list clusters for projectId: $projectId"
        continue
    fi

    # Skip the header line and iterate through each line
    echo "$cluster_list" | sed 1d | while read -r cluster; do
        cluster_name=$(echo "$cluster" | awk '{print $2}' | xargs)
        state=$(echo "$cluster" | awk '{print $4}' | xargs)
        mdb_ver=$(echo "$cluster" | awk '{print $3}' | xargs)

        project_link="[${projectId}](https://cloud.mongodb.com/v2/${projectId}#/clusters)"
        printf "| %-31s | %-20s | %-19s | %-8s | %-14s |\n" "$project_link" "$projectName" "$cluster_name" "$state" "$mdb_ver"
    done
done
IFS=$' \t\n'

