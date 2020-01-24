#!/bin/bash
workload=$1
environment=$2
az extension add --name resource-graph

# functions
function getClusterName {
  temp=`az graph query -q "Resources | where type =~ \"Microsoft.ContainerService/ManagedClusters\" | where properties.provisioningState =~ \"Succeeded\" | where tags[\"Environment\"] =~ \"$environment\" | where tags[\"Workload\"] =~ \"$workload\" | project name" -o yaml | awk '{ print $3 }'`
  echo $temp
}

function getClusterResourcegroup {
  temp=`az graph query -q "Resources | where type =~ \"Microsoft.ContainerService/ManagedClusters\" | where name =~ \"$1\" | project resourceGroup" -o yaml | awk '{ print $3 }'`
  echo $temp
}

function getClusterKubectl { 
  temp=`az aks get-credentials -g $2 -n $1`
  echo $temp
}

function deployToCluster {
  echo "Deploying to $1"
  clustername=$1
  clusterrg=$(getClusterResourcegroup $clustername)
  getClusterKubectl $clustername $clusterrg
  istioctl manifest apply --skip-confirmation
}

# main runtime
## Install kubectl
sudo az aks install-cli
export PATH=$PATH:/usr/local/bin
## Install istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

## Discover Clusters 
clusters=$(getClusterName)  
for clustername in $clusters
do
  deployToCluster $clustername
done