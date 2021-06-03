#!/bin/bash

certsDir=$1
trustStoreName=$2

keytool -keystore $trustStoreName -import -file ./$certsDir/confluentCA.pem -storepass password -noprompt
