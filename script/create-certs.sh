#!/bin/bash

components="kafka connect replicator schemaregistry ksqldb controlcenter zookeeper"

namespace=$1
exthost=$2

if [ -z $namespace ] || [ -z $exthost ]
then
    echo "Usage: create-certs.sh <namespace for deployment> <external host> "
    exit 1
fi

# Change to certs directory
if [ ! -d certs ]
then
    mkdir certs
fi

cd certs

if [ -z $(oc get secret kafka-tls --ignore-not-found=true |grep -q kafka-tls)  ]
then

    # Create new certs

    # Root key
    openssl genrsa -out confluentCA-key.pem 2048

    # Root cert
    openssl req -x509  -new -nodes -key confluentCA-key.pem -days 3650 -out confluentCA.pem -subj "/C=UK/ST=LON/L=LON/O=IBMTest/OU=Cloud/CN=TestCA"

    for component in $components
    do
        # Server key
        openssl genrsa -out $component-key.pem 2048

        # Create CSR
        openssl req -new -key $component-key.pem -out $component.csr -subj "/C=UK/ST=LON/L=LON/O=IBMTest/OU=Cloud/CN=*.$component.$namespace.svc.cluster.local"
        
        # Sign the CSR
        openssl x509 -req -in $component.csr -extensions server_ext -CA confluentCA.pem -CAkey confluentCA-key.pem -CAcreateserial -out $component.pem -days 3650 -extfile <( echo "[server_ext]"; echo "extendedKeyUsage=serverAuth,clientAuth"; echo "subjectAltName=DNS:*.$exthost,DNS:$component,DNS:*.$component,DNS:*.$component.$namespace.svc.cluster.local,DNS:$component.$namespace.svc.cluster.local")
    
        # Now create the secret
        oc create secret generic $component-tls \
            --from-file=fullchain.pem=$component.pem \
            --from-file=cacerts.pem=confluentCA.pem \
            --from-file=privkey.pem=$component-key.pem

    done
fi

cd ..
# rm -r certs

exit 0
