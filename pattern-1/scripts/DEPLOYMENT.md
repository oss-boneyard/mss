# Deployment steps:

Run deploy.sh to deploy MySQL 5.7 and WSO2 APIM 2.6.0 on K8s.
```
./deploy.sh
```
 
How to access the APIM deployment.

Add host entries.

```
cat /etc/hosts

127.0.0.1	localhost
127.0.1.1	ubuntu

10.211.55.7	wso2apim wso2apim-gateway
```

Find the APIM node port.

```
kubectl get svc -n ingress-nginx
NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
default-http-backend   ClusterIP   10.108.120.223   <none>        80/TCP                       1h
ingress-nginx          NodePort    10.110.19.219    <none>        80:31354/TCP,443:30705/TCP   1h
```

## Access the APIM.

https://wso2apim:30705/publisher/
https://wso2apim:30705/store/

