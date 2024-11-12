#!/bin/bash

# List all clusters and projects for a given Atlas organization that has clusters in a certain MongoDB version - hard-coded for 5.0 line 42

# Check if orgId is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <orgId>"
    exit 1
fi

ORG_ID=$1

# Print header
echo "| Project ID                      | Cluster Name        | MDB VER  |"
echo "|---------------------------------|---------------------|----------|"

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

    # List all clusters for the current projectId
    cluster_list=$(atlas clusters list --projectId "$projectId")
    if [ $? -ne 0 ]; then
        echo "Failed to list clusters for projectId: $projectId"
        continue
    fi

    # Skip the header line and iterate through each line
    echo "$cluster_list" | sed 1d | while read -r cluster; do
        cluster_name=$(echo "$cluster" | awk '{print $2}' | xargs)
        mdb_ver=$(echo "$cluster" | awk '{print $3}' | xargs)

        # Check if MDB VER is 5.0.*
        if [[ "$mdb_ver" =~ ^5\.0 ]]; then
            project_link="[${projectId}](https://cloud.mongodb.com/v2/${projectId}#/clusters)"
            echo "| $project_link | $cluster_name | $mdb_ver |"
        fi
    done
done
IFS=$' \t\n'
