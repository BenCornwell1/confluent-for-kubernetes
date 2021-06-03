#!/bin/bash

# Change to certs directory
if [ ! -d certs ]
then
    mkdir certs
fi

cd certs

# Root key
openssl genrsa -out confluentCA.key 2048

# Root cert
openssl req -x509  -new -nodes -key confluentCA.key -days 3650 -out confluentCA.pem -subj "/C=UK/ST=LON/L=LON/O=IBMTest/OU=Cloud/CN=TestCA"

# Clean up
cd ..

exit 0
