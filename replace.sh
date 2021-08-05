#!/bin/sh

export PATH=/bin:/usr/bin

# Check if kubectl present
if ! command -v kubectl &> /dev/null
then
    echo "kubectl: command not found"
    exit
fi

# Check if script is running on control plane or remotely
if [ -f "/etc/kubernetes/admin.conf" ] || [ ! -f "$HOME/.kube/config" ]; then
    # echo "Running on control plane"
    export KUBECONFIG=/etc/kubernetes/admin.conf
else
    if [ ! -f "/etc/kubernetes/admin.conf" ] || [ -f "$HOME/.kube/config" ]; then
        # echo "Running remotely"
        export $HOME/.kube/config
    else
        echo "Kubernetes configuration file not found"
    fi
fi

# Script variables
scriptDir="$(cd "$(dirname "$0")" && pwd)"
exportDir="${scriptDir}/export"
certDir="${scriptDir}/cert"

# Editable variable
excludeTls="" # tls1, tls2,..

# Checks
if [ ! -d "${exportDir}" ]; then mkdir ${exportDir}; fi
if [ ! -f ${certDir}/tls.key ]; then echo "Private key file '${certDir}/tls.key' not found" && exit 1; fi
if [ ! -f ${certDir}/tls.crt ]; then echo "Certificate chain file '${certDir}/tls.crt' not found" && exit 1; fi
if ! grep -q 'BEGIN RSA PRIVATE KEY\|END RSA PRIVATE KEY' "${certDir}/tls.key"; then echo "Invalid private key content" && exit 1; fi
if ! grep -q 'BEGIN CERTIFICATE\|END CERTIFICATE' "${certDir}/tls.crt"; then echo "Invalid private key content" && exit 1; fi

# key & chain variables
tlsKey=$(cat ${certDir}/tls.key | base64 -w 0)
tlsCrt=$(cat ${certDir}/tls.crt | base64 -w 0)

# If excludes present...
if [ -z "${excludeTls}" ]; then
    allTls=$(kubectl get secret -A --field-selector type=kubernetes.io/tls --no-headers | awk '{ print $1";"$2 }')
else
    if [[ $excludeTls = "," ]]; then
        format=${excludeTls/, /\\|}
    else
        format=${excludeTls}
    fi
    allTls=$(kubectl get secret -A --field-selector type=kubernetes.io/tls --no-headers | grep -v "${format}" | awk '{ print $1";"$2 }')
fi

for tls in ${allTls[@]}; do
    split=(${tls//;/ })

    echo "Exporting '${split[1]}' from '${split[0]}' namespace"
    kubectl get secret/${split[1]} -n ${split[0]} -o yaml > ${exportDir}/${split[1]}.yaml

    echo "Updating '${exportDir}/${split[1]}.yaml' file with new tls certificate and key"
    sed -i "s/^\(\s*tls.crt\s*:\s*\).*/\1${tlsCrt}/ ; s/^\(\s*tls.key\s*:\s*\).*/\1${tlsKey}/" ${exportDir}/${split[1]}.yaml

    echo "Applying '${exportDir}/${split[1]}.yaml' file"
    kubectl apply -f ${exportDir}/${split[1]}.yaml -n ${split[0]}

    echo -e "\n"
done