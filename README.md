# Deployment script for demo/PoC Confluent cluster

To deploy a cluster

```
> deploy.sh 
    <namespace> \
    <cluster ingress domain> \
    <config yaml file> \
    <kafka username> \
    <kafka password> \
    <control centre username> \
    <control centre password>
```

To remove a cluster:

```
> oc project <namespace>
> remove.sh
```
