# Luceor VPN-servers Automation Tool (LVAT)
---
> Full description of the mission

## Introduction
- Luceor labs is changing the hole workload architecture for its product, to simplify things, the project consist of migrating a desktop application to the cloud, and this was the first cloud migration for the DevOps team, before going on and start using providers like Microsoft Azure or Amazon Web Services (AWS), we decided to prepare an on-premise virtualized orchestrated environment for the testing stage of any Luceor service before migrating to the production environment on the public cloud, my mission as an intern was to deploy a full orchestrated platform on a bare-metal server with a monitoring solution and make it behaves like a PaaS environment provisioned from a public cloud, one service of the hole Luceor workload was a VPN server, and it was maintained by a vps (virtual private server) instance running on GCP (Google Cloud Platform), the new architecture is a containerized VPN server running on Kubernetes cluster, so in this module we are going to describe the subproject elaborated to automate the VPN server deployment for each Luceor customer.

##  LVAT Overview

- This module is a complex of shell and easy-rsa scripts, docker images, kubernetes manifest files, all grouped and organized in a Jenkins pipeline as stages, read the documentation to learn how to use it.

# Installation
---

<h5>Prerequistes :</h5>


> - Virtual machine with ubuntu (20.04 or 22.04)
> - Docker engin installed
> - Kubernetes cluster such as on-premise or on the cloud

 ### I- Prepare the environment

 - update the system and upgrade it for any missing packages

 ```
 sudo apt-get update
 sudo apt-get upgrade -y
 ```

 - install openvpn and easy-rsa 
 ```
 sudo apt-get install -y openvpn easy-rsa
 ```
 - For docker installation follow the official documentation from this link: https://docs.docker.com/engine/install/ubuntu/
 ### II- Build the project's working directory

 - Clone the repository into your 'working directory'
 ```bash
 git clone https://github.com/jihedmakthri/LuceorLabs.git
 ```
 - get into your 'working directory' and delete the easy-rsa directory then create a new one with this command
 ```bash
 sudo make-cadir /path/to/your/working-directory/easy-rsa
 ``` 
 - initialize the easy-rsa PKI system and build your root certificates for the openVPN servers and clients:
 
 <ins>Before proceeding, make sure you edit the vars file in the easy-rsa directory to match tour needs, check easy-rsa documentation from this link: https://easy-rsa.readthedocs.io/en/latest/advanced/</ins>

 ```bash
 cd /path/to/your/working-directory/easy-rsa
 ./easyrsa init-pki
./easyrsa build-ca nopass
 ```
### III- Install Jenkins Continues integration server

> * Click on the link below and follow the installation steps from the official documentation page of Jenkins:
Visit https://www.jenkins.io/doc/book/installing/linux/#debianubuntu

### IV- Configure the project scripts
-- *Description :*
The following script *gencas.sh* is responsible for creating all necessary files to build an openVPN server:
>- server's private key 
>- server's certificate
>- TLS-auth key
>- Deffie-Helman key
>- configuration file for the openvpn server

 The code build a full configuration file for VPN server with options passed to the command, here's a preview of the command's arguments:

```
--- command --- ./gencas.sh

--- options ---

 --CN <common name for the VPN certificates>
 --ServerName <name with which you want to create the server , generally it's the name of the client and the same as the common name>
 --Network <network adresse from which the vpn server will give IPs to clients>
 --Masque <masque addresse of the network, must be in full format do not use CIDR annotation>
 --Port <port of the server, each time you have to renew this one you cannot use the same port two times>
 --Protocol <use only lower case and you have only two options "udp/tcp">
 --NicName <the name of the interface that will be created on the server for the vpn tunnel, example: "tun0">
 --ClientToCLient <this option takes a 'yes' or 'no', if yes, clients connected to the server will be able to connect with each other>
 --DeviceType <device type for the tunnel 'tun' mode or 'tap' mode>
 --Verbosity <verbosity of the stdout>
```

- open the shell script **gencas.sh** in your editor or with nano and edit it to match your work lab:

```bash
#!/bin/bash
# Function to print script usage
print_usage() {
    echo "Usage: $0 --CN <common_name> --ServerName <server_name> --Network <network> --Masque <masque> --Port <port> --Protocol <protocol> --NicName <nic_name> --ClientToClient <client_to_client> --DeviceType <device_type> --Verbosity <verbosity>"
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --CN)
            CN="$2"
            shift 2
            ;;
        --ServerName)
            SERVER_NAME="$2"
            shift 2
            ;;
        --Network)
            VPN_SERVER_NETWORK="$2"
            shift 2
            ;;
        --Masque)
            VPN_SERVER_MASQUE="$2"
            shift 2
            ;;
        --Port)
            VPN_PORT="$2"
            shift 2
            ;;
        --Protocol)
            VPN_PROTOCOL="$2"
            shift 2
            ;;
        --NicName)
            NIC_NAME="$2"
            shift 2
            ;;
        --ClientToClient)
            CLIENT_TO_CLIENT="$2"
            shift 2
            ;;
        --DeviceType)
            DEVICE_TYPE="$2"
            shift 2
            ;;
        --Verbosity)
            VPN_VERBOSITY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z $CN || -z $SERVER_NAME || -z $VPN_SERVER_NETWORK || -z $VPN_SERVER_MASQUE || -z $VPN_PORT || -z $VPN_PROTOCOL || -z $NIC_NAME || -z $CLIENT_TO_CLIENT || -z $DEVICE_TYPE || -z $VPN_VERBOSITY ]]; then
    echo "Missing required argument(s)"
    print_usage
fi

#replace the base_path variable with your working directory
base_path="/path/to/your/working-directory"
cd $base_path/easy-rsa

#generate server request
echo $CN | ./easyrsa gen-req $SERVER_NAME nopass
#signing the request of the server with the root ca
echo yes | ./easyrsa sign-req server $SERVER_NAME
#generates Deffir-Hellman parameters
./easyrsa gen-dh
#generate the TLS-auth key
openvpn --genkey --secret ta.key
#make directory for the server created, generate config file and copy all to the server directory
mkdir $base_path/VPNs/$SERVER_NAME
cp pki/ca.crt $base_path/VPNs/$SERVER_NAME 
touch $base_path/VPNs/$SERVER_NAME/server.conf
mv pki/dh.pem ta.key pki/issued/$SERVER_NAME.crt pki/private/$SERVER_NAME.key $base_path/VPNs/$SERVER_NAME
cp $base_path/vpnSHELLclient-0.0.1-SNAPSHOT.jar $base_path/VPNs/$SERVER_NAME
generate_openvpn_config(){
cat << EOF
server $VPN_SERVER_NETWORK $VPN_SERVER_MASQUE
port $VPN_PORT
dh /etc/openvpn/server/dh.pem
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/$SERVER_NAME.crt
key /etc/openvpn/server/$SERVER_NAME.key
tls-auth /etc/openvpn/server/ta.key 0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
proto $VPN_PROTOCOL
dev $NIC_NAME
dev-type $DEVICE_TYPE
persist-key
persist-tun
cipher AES-256-CBC
verb $VPN_VERBOSITY
EOF

	if [ "$CLIENT_TO_CLIENT" = "yes" ]; then
  		echo "client-to-client"
	fi

    if [ "$VPN_PROTOCOL" = "udp" ]; then
        echo "explicit-exit-notify 1"
    fi

cat << EOF
keepalive 10 120
max-clients 135
mute 20
status /var/log/openvpn/openvpn-status.log
status-version 3
EOF
}
server_config="$base_path/VPNs/$SERVER_NAME/server.conf"
generate_openvpn_config $CN $SERVER_NAME > $server_config

#copy the 'entrypoint.sh' for the build context of the image
cp $base_path/entrypoint.sh $base_path/VPNs/$SERVER_NAME/
#generate a dockerfile for the image building
touch $base_path/VPNs/$SERVER_NAME/Dockerfile
#the base image is located at jihedmakthri/luceorvpn
#do not change the image tag
generate_dockerfile(){
cat << EOF
FROM jihedmakthri/luceorvpn:abstract1.1
WORKDIR /etc/openvpn/server
COPY ca.crt ta.key $SERVER_NAME.crt $SERVER_NAME.key server.conf dh.pem /etc/openvpn/server
COPY vpnSHELLclient-0.0.1-SNAPSHOT.jar /app.jar
COPY entrypoint.sh /start.sh
EXPOSE 8032
CMD ["/start.sh"]
EOF
}

Dockerfile="$base_path/VPNs/$SERVER_NAME/Dockerfile"
generate_dockerfile $CN $SERVER_NAME > $Dockerfile
```
---
#### --- Image of the server ---
The docker image mentioned in the script while creating the Dockerfile "jihedmakthri/luceorvpn:abstract1.1" is a custom docker image based on ubuntu 22.04, it contains a prepared environment with openvpn installed into it and easy-rsa system, openvpn exporter for prometheus that exports metrics on the /metrics path and port 9176.
In order to build your own image, run a container with the image mentioned earlier and past your ca.key in /etc/openvpn/easy-rsa/pki/private and your ca.crt in /etc/openvpn/easy-rsa/pki to build VPN servers with your root CA,
commit the container with a tag of your choice and you can just use it locally 

> In case of executing the gencas.sh script manually on your local machine you will create a full build context and necessary files for the VPN server to run.
> --- In the next stage you will configure your jenkins pipeline to automate image building of the newly created vpn server and push it on docker hub then deploy it on kubernetes cluster ---

### V- Configure jenkins pipeline

- Before going further, change the ownership of your working directory to jenkins user to avoid any "Permission denied" problem while starting the pipeline.

```bash
sudo chown -R jenkins:jenkins /path/to/your/working-directory
```
> If you encounter any permission denied problemes after doing this, check read, write, execute rights on all files concerned and causing errors. use the *chmod* command.

- Open jenkins in your browser, create a '*new-item*->*pipeline*', then copy pase the content of the **pipeline.groovy** file from your working directory into the script field on your browser and edit it to match your lab options.

*Before proceeding, create a secret file in your repo named ".dockerpass.txt" and right into it your docker hub password, then create a file named "kubeConfig" and pass into it credentials of your kubernetes cluster*
```js
pipeline {
    agent any

    environment {
        DOCKER_HUB_REPO = 'username/your-repository' // Replace with your Docker Hub repo
        KUBE_NAMESPACE = 'xxxxx' // Replace with your Kubernetes namespace
        base_path = '/path/to/your/working-directory' //Replace to the working directory that contains the hole project, use absolute path /.... 
        SHELL = '/bin/bash' //do not change this
        IMAGE_TAG = "${env.customer_name}-vpn" //do not change this

    //theses are arguments of the script gencas.sh
        server_cn = 'server-common-name' // Replace with your actual values
        customer_name = 'your-client-name' // Replace with your actual values and do not use '_' only -normal dash '-' 
        VPN_SERVER_NETWORK = 'a.b.c.d'
        VPN_SERVER_MASQUE = 'x.y.z.f'
        VPN_PORT = '0000'
        VPN_PROTOCOL = 'udp'
        NIC_NAME = 'tun0'
        CLIENT_TO_CLIENT = 'yes'
        DEVICE_TYPE = 'tun'
        VPN_VERBOSITY = '3'
        
    }

    stages {
        stage('Generate PKI and Dockerfile') {
            steps {
                script {
                    def scriptPath = "${base_path}/gencas.sh" // Replace with the actual path
                    sh "${scriptPath} --CN ${env.server_cn} --ServerName ${env.customer_name} --Network ${env.VPN_SERVER_NETWORK} --Masque ${env.VPN_SERVER_MASQUE} --Port ${env.VPN_PORT} --Protocol ${env.VPN_PROTOCOL} --NicName ${env.NIC_NAME} --ClientToClient ${env.CLIENT_TO_CLIENT} --DeviceType ${env.DEVICE_TYPE} --Verbosity ${env.VPN_VERBOSITY}"
                    
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    def dockerfilePath = "${base_path}/VPNs/${env.customer_name}/Dockerfile"
                        sh "docker build --no-cache -t ${env.IMAGE_TAG} -f ${dockerfilePath} ${base_path}/VPNs/${env.customer_name}"
                        sh "docker tag ${env.IMAGE_TAG} ${env.DOCKER_HUB_REPO}:${env.IMAGE_TAG}"
                        //change the USERNAME with your docker hub username
                        sh "cat ${base_path}/.dockerpass.txt | docker login --username USERNAME --password-stdin"
                        sh "docker push ${env.DOCKER_HUB_REPO}:${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Generate Manifests') {
            steps {
                script {
                    def templatePath = '${base_path}/server-deployment-template.yaml'
                    def template = readFile(templatePath)
                    echo "Loaded template from: ${templatePath}"

                    def manifest = template
                        .replaceAll('CLIENT_SERVER_NAME', env.customer_name)
                        .replaceAll('IMAGE_TAG', env.IMAGE_TAG)
                        .replaceAll('VPN_PORT', env.VPN_PORT)
                        .replaceAll('VPN_PROTOCOL', env.VPN_PROTOCOL.toUpperCase())

                    def outputPath = "${base_path}/VPNs/${env.customer_name}/${env.customer_name}-server-deployment.yaml"
                    echo "Writing manifest to: ${outputPath}"
                    writeFile(file: outputPath, text: manifest)
                }
            }
        }
        

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def kubeConfig = "${base_path}/kubeConfig"
                    def namespaceExists = sh(script: "kubectl --kubeconfig=${kubeConfig} get namespace ${env.KUBE_NAMESPACE} --output=name", returnStatus: true) == 0

                    if (!namespaceExists) {
                        sh "kubectl --kubeconfig=${kubeConfig} create namespace ${env.KUBE_NAMESPACE}"
                    } else {
                         echo "Namespace ${env.KUBE_NAMESPACE} already exists"
                    }
                    sh "kubectl --kubeconfig=${kubeConfig} apply -f ${base_path}/VPNs/${env.customer_name}/${env.customer_name}-server-deployment.yaml -n ${env.KUBE_NAMESPACE}"
                }
            }
        }
    }
}
```
#### --- Kubernetes template ---
The **server-deployment-template.yaml** file is the template required to create manifest file for the full deployment of the VPN server (deployment, service, persistantVolumeClaim), on the stage *'Generate Manifests'*, a manifest file is created into the server directory with the right names, labels, port configurations and layer 3 protocols, ready for the next stage to deploy the server to your customer.
>**RQ:** I used nfs-client as the storageClasse for the PVC, change the storageClass to match your needs if you are working with other classes or with cloud provider persistant storage service. **BUT** Do not try to change any other thing in any generated files. YAML files and the pipeline script are very sensitive.
- Here's an overview of the kubernetes templating file:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: CLIENT_SERVER_NAME-server
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "9176"
  labels:
    app: CLIENT_SERVER_NAME-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: CLIENT_SERVER_NAME-server
  template:
    metadata:
      labels:
        app: CLIENT_SERVER_NAME-server
    spec:
      containers:
      - name: CLIENT_SERVER_NAME
        image: jihedmakthri/vpn-servers:IMAGE_TAG
        ports:
        - containerPort: VPN_PORT
          protocol: VPN_PROTOCOL
        - containerPort: 9176
          protocol: TCP
        - containerPort: 8032
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
          privileged: true
        env:
        - name: KUBE_VPN_SERVICE_NAME
          value: CLIENT_SERVER_NAME-service
        resources:
          limits:
            cpu: 1000m
            memory: 2048Mi
          requests:
            cpu: 200m
            memory: 512Mi
        volumeMounts:
        - name: CLIENT_SERVER_NAME-storage
          mountPath: /var/log/openvpn
        - name: CLIENT_SERVER_NAME-client-config
          mountPath: /etc/openvpn/client
      volumes:
      - name: CLIENT_SERVER_NAME-storage
        persistentVolumeClaim:
          claimName: CLIENT_SERVER_NAME-claim-logs
      - name: CLIENT_SERVER_NAME-client-config
        persistentVolumeClaim:
          claimName: CLIENT_SERVER_NAME-claim
---

apiVersion: v1
kind: Service
metadata:
  name: CLIENT_SERVER_NAME-service
  labels:
    app: CLIENT_SERVER_NAME-server
spec:
  type: LoadBalancer
  ports:
  - name: vpn
    port: VPN_PORT
    targetPort: VPN_PORT
    protocol: VPN_PROTOCOL
  - name: exporter
    port: 9176
    targetPort: 9176
    protocol: TCP
  - name: http
    port: 8032
    targetPort: 8032
  selector:
      app: CLIENT_SERVER_NAME-server

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: CLIENT_SERVER_NAME-claim-logs
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: CLIENT_SERVER_NAME-claim
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 4Gi

```
>---
>##### <ins> After completing all steps, run the pipeline and always check logs for any mistakes.</ins> #####
>---

### VI- Generate clients for the server deployed
- The deployed server now contains 3 running services:
    - VPN service
    - Metrics exporter for Prometheus
    - Service for VPN-clients generation

#### --- VPN clients generation process ---
A java application is added while creation of the server image in the jenkins pipeline and it's mentioned in the Dockerfile created by the *gencas.sh*, this application in the project named "*vpnSHELLclient-0.0.1-SNAPSHOT.jar*", a springboot app that triggers an other BASH script inside the server *gencas-client.sh*.
The java app containes one API that you can reach with a http POST method from outside. 
- For each server deployed :
  - you must follow this form of http post method:

  >http://example.domain:8032/NAME-OF-KUBERNETES-VPN-SERVICE/generateclient
  >Replace example.domain with your DNS record saved for the access to vpn servers inside the cluster,Replace NAME-OF-KUBERNETES-VPN-SERVICE with the vpn kubernetes service name deployed earlier ( it's always : ${customer_name}-service) *customer_name* is the name used in the jenkins pipeline.

  **- why this form exactly ?**
    - The *example.domain* is the domain used in the kubernetes Ingress object, you have to configure your ingress mapping and forwarding, for Example:

      ```yaml
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: example-ingress
        annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /$1
      spec:
        rules:
          - host: example.domain
            http:
              paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: web
                      port:
                        number: 8080
      ```  
    - You can open *Postman* and try the POST method, pass into the body as JSON format { "clientName" : "example-client01" }, or you can try with the command below on your terminal:

    ```bash
    curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"clientName": "client01"}' \
  http://example.domain:8032/NAME-OF-KUBERNETES-VPN-SERVICE/generateclient

    #Replace example.domain, NAME-OF-KUBERNETES-VPN-SERVICE, and the URL path as needed.
    ```
This POST request consumes the *triggerScript()* API in the server and the API it self triggers the script *gencas-client.sh*, this script creates the necessary files (ta.key, ca.crt client.crt, client.key, client.conf) based on the VPN server running and store them in a zip file titled with the attribute passed into the body of the POST method:

 - *genca-client.sh:*

```bash
cd /etc/openvpn/easy-rsa

echo $1 | ./easyrsa gen-req $1 nopass
echo yes | ./easyrsa sign-req client $1

mkdir /etc/openvpn/client/$1


cp -f --no-preserve=mode,ownership pki/issued/$1.crt pki/private/$1.key /etc/openvpn/client/$1
rm -f pki/issued/$1.crt pki/private/$1.key 
cp --no-preserve=mode,ownership /etc/openvpn/server/ca.crt /etc/openvpn/server/ta.key /etc/openvpn/client/$1
touch /etc/openvpn/client/$1/client.conf

generate_openvpn_config(){
cat << EOF
client
remote-cert-tls server
resolv-retry infinite
nobind
persist-key
persist-tun
mute-replay-warnings
cipher AES-256-CBC
EOF
echo "remote YOUR.DOMAIN.HERE $(grep 'port' /etc/openvpn/server/server.conf | awk '{print $2}')"
echo "dev $(grep 'dev-type' /etc/openvpn/server/server.conf | awk '{print $2}')"
echo "proto $(grep 'proto' /etc/openvpn/server/server.conf | awk '{print $2}')"
cat << EOF
ca ca.crt
cert $1.crt
key $1.key
tls-auth ta.key 1
verb 3
EOF
}
generate_openvpn_config $1 > /etc/openvpn/client/$1/client.conf

zip -r /etc/openvpn/client/$1.zip /etc/openvpn/client/$1
rm -rf /etc/openvpn/client/$1

``` 
> <ins>NOTE:</ins> that while your building the base image for your VPN servers creation, don't forget to change *YOUR.DOMAIN.HERE* with your actual dns record reserved for the VPN service

- Finally you will find each client created on the persistant volume storage that you have chosen before. <ins>Return to the kubernetes templating file for more details</ins>.




# Updates
---
-  This section is about new updated version of the LVAT, added items:
   - Nginx ingress controller
   - Non-http/https routing through Ingress controller
 
### I- Nginx Ingress Controller deployment

If you don't have an Ingress controller deployed on your cluster then follow these steps to install *Nginx Ingress Controller*:

>before executing the command, check compatibility of the controller version with your kubernetes actual version, follow this link: <ins>https://github.com/kubernetes/ingress-nginx</ins>

command:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.6.4/deploy/static/provider/cloud/deploy.yaml
```
check if the Ingress controller have been installed correctly, you should see something like thing:

```console
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-htjdr        0/1     Completed   0          22h
ingress-nginx-admission-patch-xkjf7         0/1     Completed   2          22h
ingress-nginx-controller-5799479596-68p8s   1/1     Running     0          148m
```
Now  deploy two config maps named "udp-services" and "tcp-services" in the same namespace where the ingress controller is deployed:

*udp-services.yaml :*
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: udp-services
  namespace: ingress-nginx
data:
```

*tcp-services.yaml :*
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
data:
```
<ins> *you can find these files under /ingress in your working directory after cloning the project.*</ins>

Now patch the Ingress controller deployment to take effects from the last configmaps deployed:
```json
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type json -p \
  '[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--udp-services-configmap=$(POD_NAMESPACE)/udp-services"
  }]'
```

- **In order to configure nginx server to route UDP traffic you have to add some arguments to ingress controller default configmap: **
```bash
kubectl patch configmap ingress-nginx-controller -n ingress-nginx --type=json -p='[{"op": "add", "path": "/data/proxy-stream-responses", "value": "2"}]'
```
> **Quick Fix Bug :**
>> - This modification make the nginx server not pretending any response from the targeted server, because UDP (User Datagram Protocol) is a no-mode packet transport protocol which allows to send a message without acknowledgment, and if you don't force the proxy-stream-responses value to 2 or upper, client will not be able to connect to the UDP based VPN server in the cluster.
### IV- Manifest file template update
We have added an ingress object into the *server-deployment-template.yaml* so you can simply generate clients for your vpn server with postman or 'curl' command as shown in this [Section](#vpn-clients-generation-process)
- Ingress template:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: CLIENT_SERVER_NAME-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: YOUR.DOMAIN.HERE
      http:
        paths:
          - path: /CLIENT_SERVER_NAME-service/generateclient
            pathType: Prefix
            backend:
              service:
                name: CLIENT_SERVER_NAME-service
                port:
                  number: 8032
```
### III- Configure Jenkins pipeline for new updates
- Added these lines to the jenkins pipeline to route UDP/TCP traffic to allow each client to connect to it's vpn server:

```groovy
echo "patching nginx ingress configmaps and service to route udp/tcp traffic for the server created..."
                    
  sh "kubectl --kubeconfig=${kubeConfig} apply -f ${base_path}/VPNs/${env.customer_name}/${env.customer_name}-server-deployment.yaml -n ${env.KUBE_NAMESPACE}"
  if(env.VPN_PROTOCOL == "udp"){
      sh """
      kubectl --kubeconfig=${kubeConfig} patch configmap udp-services -n ${env.INGRESS_NAMESPACE} --type=json -p='[{"op": "add", "path": "/data/${env.VPN_PORT}", "value": "${env.KUBE_NAMESPACE}/${env.customer_name}-service:${env.VPN_PORT}"}]'
      """
      sh """
      kubectl --kubeconfig=${kubeConfig} patch service ingress-nginx-controller -n ${env.INGRESS_NAMESPACE} --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "${env.customer_name}-service-${env.VPN_PROTOCOL}","port": ${env.VPN_PORT},"protocol": "UDP","targetPort": ${env.VPN_PORT}}}]'
      """
  }else{
      sh """
      kubectl --kubeconfig=${kubeConfig} patch configmap tcp-services -n ${env.INGRESS_NAMESPACE} --type=json -p='[{"op": "add", "path": "/data/${env.VPN_PORT}", "value": "${env.KUBE_NAMESPACE}/${env.customer_name}-service:${env.VPN_PORT}"}]'
      """
      sh """
      kubectl --kubeconfig=${kubeConfig} patch service ingress-nginx-controller -n ${env.INGRESS_NAMESPACE} --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "${env.customer_name}-service-${env.VPN_PROTOCOL}","port": ${env.VPN_PORT},"protocol": "TCP","targetPort": ${env.VPN_PORT}}}]'
      """
  }
```

> <ins>**Don't forget to add a new Variable to the pipeline: INGRESS_NAMESPACE**</ins>




