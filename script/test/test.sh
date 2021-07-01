#!/bin/bash

namespace=$1
filename=$2

index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' ../config.yaml)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' ../config.yaml)
    echo $type
    echo "$fileContent" > $type.yaml

    ((index=index+1))
    fileContent=$(i=$index yq eval 'select(di == env(i))' ../config.yaml)

done

if [ -e ControlCenter.yaml ]
then
    if [ -e Connect.yaml ]
    then
        yq eval -i ".spec.dependencies.connect.[0].url = \"http://connect.$namespace.svc:8083\"" ControlCenter.yaml      
    fi

    if [ -e SchemaRegistry.yaml ]
    then
        yq eval -i ".spec.dependencies.schemaRegistry.url = \"http://schemaregistry.$namespace.svc:8081\"" ControlCenter.yaml
    fi

    if [ -e KsqlDB.yaml ]
    then
        yq eval -i ".spec.dependencies.ksqldb.[0].url = \"http://ksqldb.$namespace.svc:8081\"" ControlCenter.yaml
    fi
fi
