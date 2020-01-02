#!/bin/bash

clientid=$1
clientsecret=$2
subscriptionid=$3
module=$4
environment=$5
workload=$6
registry=$7
tenantid=$8

az login --service-principal -u "$clientid" -p "$clientsecret" --tenant "$tenantid"
az account set -s "$subscriptionid"
az extension add --name resource-graph
az graph query -q "Resources | where type =~ \"Microsoft.ContainerService/ManagedClusters\" | where properties.provisioningState =~ \"Succeeded\" | where tags[\"Environment\"] =~ \"$environment\" | where tags[\"Workload\"] =~ \"$workload\" | project name" -o yaml | awk '{ print $3 }' | xargs -I % sh -c "az aks update -g \"$workload-$environment-$module\" -n % --attach-acr \"$registry\";"
exit $?
