#!/bin/bash
workload=$1
environment=$2
namespace=$3
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

function getTrafficManager {
  component=$1
  temp=`az graph query -q "Resources | where type =~ \"Microsoft.Network/trafficManagerProfiles\" | where tags[\"Component\"] =~ \"$component\" | where tags[\"Environment\"] =~ \"$environment\" | where tags[\"Workload\"] =~ \"$workload\" | project name" -o yaml | awk '{ print $3 }'`
  echo $temp
}

function getTrafficManagerResourcegroup {
  temp=`az graph query -q "Resources | where type =~ \"Microsoft.Network/trafficManagerProfiles\" | where name =~ \"$1\" | project resourceGroup" -o yaml | awk '{ print $3 }'`
  echo $temp
}

function addIstioGatewayToTrafficManager {
  servicename=`kubectl get services | grep -i "istio-ingressgateway" | awk '{ print $1 }'`
  external_ip=""
  while [ -z $external_ip ]; do
    echo "Waiting for end point..."
    external_ip=$(kubectl get svc "$servicename" --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$external_ip" ] && sleep 10
  done
  echo 'End point ready:' && echo $external_ip
  clustername=$1
  component=$2
  tmname=$(getTrafficManager $component)
  tmrg=$(getTrafficManagerResourcegroup $tmname)
  weight=1
  az network traffic-manager endpoint create --resource-group "$tmrg" --profile-name "$tmname" --type externalEndpoints --name "$clustername" --target "$external_ip" --weight $weight
}

function deployToCluster {
  echo "Deploying to $1"
  clustername=$1
  clusterrg=$(getClusterResourcegroup $clustername)
  getClusterKubectl $clustername $clusterrg
  istioctl manifest apply --skip-confirmation
  kubectl label namespace $namespace istio-injection=enabled
  addIstioGatewayToTrafficManager $clustername "api"
  addIstioGatewayToTrafficManager $clustername "www"
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