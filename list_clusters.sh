#!/bin/bash

# Uses Atlas CLI to list all 5.0 clusters in a given organization

# Check if orgId is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <orgId>"
    exit 1
fi

ORG_ID=$1

# List all projects for the given orgId
project_list=$(atlas projects list --orgId "$ORG_ID")

# Skip the header line and iterate through each line
echo "$project_list" | sed 1d | while read -r project; do
    projectId=$(echo "$project" | awk '{print $1}')

    # List all clusters for the current projectId
    cluster_list=$(atlas clusters list --projectId "$projectId")

    # Skip the header line and iterate through each line
    echo "$cluster_list" | sed 1d | while read -r cluster; do
        cluster_name=$(echo "$cluster" | awk '{print $2}')
        mdb_ver=$(echo "$cluster" | awk '{print $3}')

        # Check if MDB VER is 5.0.*
        if [[ "$mdb_ver" =~ ^5\.0 ]]; then
            echo "Project ID: $projectId, Cluster Name: $cluster_name, MDB VER: $mdb_ver"
        fi
    done
done
