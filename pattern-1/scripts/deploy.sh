#!/bin/bash

# ------------------------------------------------------------------------
# Copyright 2017 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------

set -e

ECHO=`which echo`
KUBECTL=`which kubectl`

# methods
function echoBold () {
    ${ECHO} -e $'\e[1m'"${1}"$'\e[0m'
}

function usage () {
    echoBold "This script automates the installation of WSO2 EI Integrator Analytics Kubernetes resources\n"
    echoBold "Allowed arguments:\n"
    echoBold "-h | --help"
    echoBold "--wu | --wso2-username\t\tYour WSO2 username"
    echoBold "--wp | --wso2-password\t\tYour WSO2 password"
    echoBold "--cap | --cluster-admin-password\tKubernetes cluster admin password\n\n"
}

function create_mysql_server_storage () {
    #Create folders required by the mysql PVC
    if [ -d /mnt/mysql ]; then
        sudo mv /mnt/mysql "/mnt/mysql.$(date +%s)"
    fi
    sudo mkdir -p /mnt/mysql
    #Change the folder ownership to mysql server user.
    sudo chown 999:999 /mnt/mysql
}

function create_apim_artifact_storage () {
#Create folders required by the APIM GW PVC
if [ -d /mnt/apim_repository_deployment_server ]; then
            sudo mv /mnt/apim_repository_deployment_server "/mnt/apim_repository_deployment_server.$(date +%s)"
fi
#Create folders required by the APIM PVC
sudo mkdir -p /mnt/apim_repository_deployment_server
sudo chown 802:802 /mnt/apim_repository_deployment_server
}

WSO2_SUBSCRIPTION_USERNAME=''
WSO2_SUBSCRIPTION_PASSWORD=''
ADMIN_PASSWORD=''

# capture named arguments
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`

    case ${PARAM} in
        -h | --help)
            usage
            exit 1
            ;;
        --wu | --wso2-username)
            WSO2_SUBSCRIPTION_USERNAME=${VALUE}
            ;;
        --wp | --wso2-password)
            WSO2_SUBSCRIPTION_PASSWORD=${VALUE}
            ;;
        --cap | --cluster-admin-password)
            ADMIN_PASSWORD=${VALUE}
            ;;
        *)
            echoBold "ERROR: unknown parameter \"${PARAM}\""
            usage
            exit 1
            ;;
    esac
    shift
done

HOST_NAME=$(hostname | tr '[:upper:]' '[:lower:]')
#${KUBECTL} label nodes $HOST_NAME disk=local

# create a new Kubernetes Namespace
${KUBECTL} create namespace wso2

# create a new service account in 'wso2' Kubernetes Namespace
${KUBECTL} create serviceaccount wso2svc-account -n wso2

# switch the context to new 'wso2' namespace
${KUBECTL} config set-context $(${KUBECTL} config current-context) --namespace=wso2

# create a Kubernetes Secret for passing WSO2 Private Docker Registry credentials
#${KUBECTL} create secret docker-registry wso2creds --docker-server=docker.wso2.com --docker-username=${WSO2_SUBSCRIPTION_USERNAME} --docker-password=${WSO2_SUBSCRIPTION_PASSWORD} --docker-email=${WSO2_SUBSCRIPTION_USERNAME}

# create Kubernetes Role and Role Binding necessary for the Kubernetes API requests made from Kubernetes membership scheme
#${KUBECTL} create --username=admin --password=${ADMIN_PASSWORD} -f ../../rbac/rbac.yaml

echoBold 'Creating ConfigMaps...'
${KUBECTL} create configmap apim-conf --from-file=../confs/apim/
${KUBECTL} create configmap apim-conf-datasources --from-file=../confs/apim/datasources/
#${KUBECTL} create configmap apim-analytics-conf-worker --from-file=../confs/apim-analytics/conf/worker/
${KUBECTL} create configmap mysql-dbscripts --from-file=../extras/confs/rdbms/mysql/dbscripts/

# MySQL
echoBold 'Deploying WSO2 API Manager Databases...'
#Create folder for the mysql storage
create_mysql_server_storage
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-persistent-volume-claim.yaml
#${KUBECTL} create -f ../extras/rdbms/volumes/persistent-volumes.yaml
${KUBECTL} create -f ../extras/rdbms/volumes/mysql-persistent-volumes-local.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-deployment.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-service.yaml

sleep 60s

#echoBold 'Deploying WSO2 API Manager Analytics...'
#${KUBECTL} create -f ../apim-analytics/wso2apim-analytics-deployment.yaml
#${KUBECTL} create -f ../apim-analytics/wso2apim-analytics-service.yaml
#sleep 200s

echoBold 'Deploying WSO2 API Manager...'
#Create folder for the apim artifact storage
create_apim_artifact_storage 
${KUBECTL} create -f ../volumes/apim-persistent-volumes-local.yaml
${KUBECTL} create -f ../apim/wso2apim-volume-claim.yaml
${KUBECTL} create -f ../apim/wso2apim-deployment.yaml
${KUBECTL} create -f ../apim/wso2apim-service.yaml

sleep 10s

echoBold 'Deploying Ingresses...'
${KUBECTL} create -f ../ingresses/wso2apim-ingress.yaml
${KUBECTL} create -f ../ingresses/mandatory.yaml
${KUBECTL} create -f ../ingresses/service-nodeport.yaml

echoBold 'Finished'
