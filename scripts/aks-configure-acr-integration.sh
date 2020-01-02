#!/bin/bash
export
echo $1
echo $2
echo $3
echo $4
echo $5
echo $6
echo $7
az login -u $(ARMCLIENTID) -p $(ARMCLIENTSECRET)
az account set -s $(armsubscriptionid)
az extension add --name resource-graph
az graph query -q "Resources" | where type =~ 'Microsoft.ContainerService/ManagedClusters' | where tags['Environment'] =~ "$(parameters.stage)" | where tags['Workload'] =~ "$(workload)" | project "name" -o yaml | awk '{ print $3 }' | xargs -I % sh -c 'az aks update -g "$(parameters.stage)-$(workload)-$(parameters.module)" -n % --attach-acr "$(registry)";'