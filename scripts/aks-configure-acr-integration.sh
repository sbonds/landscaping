#!/bin/bash
clientid=$1
clientsecret=$2
subscriptionid=$3
module=$4
environment=$5
workload=$6
registry=$7
az login -u "$(clientid)" -p "$(clientsecret)"
az account set -s "$(subscriptionid)"
az extension add --name resource-graph
az graph query -q "Resources" | where type =~ 'Microsoft.ContainerService/ManagedClusters' | where tags['Environment'] =~ "$(environment)" | where tags['Workload'] =~ "$(workload)" | project "name" -o yaml | awk '{ print $3 }' | xargs -I % sh -c "az aks update -g \"$(environment)-$(workload)-$(module)\" -n % --attach-acr \"$(registry)\";"
exit $?