pipeline {
    agent any

    environment {
        server_cn = 'jihed' // Replace with your actual values
        Luceor_client = 'jihed3' // Replace with your actual values
        DOCKER_HUB_REPO = 'jihedmakthri/vpn-servers' // Replace with your Docker Hub repo
        KUBE_NAMESPACE = 'jihed' // Replace with your Kubernetes namespace
        base_path = '/home/jihed/luceorVPNserver-automation'
        SHELL = '/bin/bash'
        VPN_SERVER_NETWORK = '10.8.0.0'
        VPN_SERVER_MASQUE = '255.255.255.0'
        VPN_PORT = '1195'
        VPN_PROTOCOL = 'udp'
        NIC_NAME = 'tun0'
        CLIENT_TO_CLIENT = 'yes'
        DEVICE_TYPE = 'tun'
        VPN_VERBOSITY = '3'
        IMAGE_TAG = "${env.Luceor_client}-vpn"
    }

    stages {
        stage('Generate PKI and Dockerfile') {
            steps {
                script {
                    def scriptPath = "${base_path}/gencas.sh" // Replace with the actual path
                    sh "${scriptPath} --CN ${env.server_cn} --ServerName ${env.Luceor_client} --Network ${env.VPN_SERVER_NETWORK} --Masque ${env.VPN_SERVER_MASQUE} --Port ${env.VPN_PORT} --Protocol ${env.VPN_PROTOCOL} --NicName ${env.NIC_NAME} --ClientToClient ${env.CLIENT_TO_CLIENT} --DeviceType ${env.DEVICE_TYPE} --Verbosity ${env.VPN_VERBOSITY}"
                    
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    def dockerfilePath = "${base_path}/VPNs/${env.Luceor_client}/Dockerfile"
                        sh "docker build --no-cache -t ${env.IMAGE_TAG} -f ${dockerfilePath} ${base_path}/VPNs/${env.Luceor_client}"
                        sh "docker tag ${env.IMAGE_TAG} ${env.DOCKER_HUB_REPO}:${env.IMAGE_TAG}"
                        sh "cat ${base_path}/.dockerpass.txt | docker login --username jihedmakthri --password-stdin"
                        sh "docker push ${env.DOCKER_HUB_REPO}:${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Generate Manifests') {
            steps {
                script {
                    def templatePath = '/home/jihed/luceorVPNserver-automation/server-deployment-template.yaml'
                    def template = readFile(templatePath)
                    echo "Loaded template from: ${templatePath}"

                    def manifest = template
                        .replaceAll('CLIENT_SERVER_NAME', env.Luceor_client)
                        .replaceAll('IMAGE_TAG', env.IMAGE_TAG)
                        .replaceAll('VPN_PORT', env.VPN_PORT)
                        .replaceAll('VPN_PROTOCOL', env.VPN_PROTOCOL.toUpperCase())

                    def outputPath = "${base_path}/VPNs/${env.Luceor_client}/${env.Luceor_client}-server-deployment.yaml"
                    echo "Writing manifest to: ${outputPath}"
                    writeFile(file: outputPath, text: manifest)
                }
            }
        }
        

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def kubeConfig = "${base_path}/kubeConfig" // Replace with your Jenkins credentials ID for Kubernetes config
                    def namespaceExists = sh(script: "kubectl --kubeconfig=${kubeConfig} get namespace ${env.KUBE_NAMESPACE} --output=name", returnStatus: true) == 0

                    if (!namespaceExists) {
                        sh "kubectl --kubeconfig=${kubeConfig} create namespace ${env.KUBE_NAMESPACE}"
                    } else {
                         echo "Namespace ${env.KUBE_NAMESPACE} already exists"
                    }
                    sh "kubectl --kubeconfig=${kubeConfig} apply -f ${base_path}/VPNs/${env.Luceor_client}/${env.Luceor_client}-server-deployment.yaml -n ${env.KUBE_NAMESPACE}"
                }
            }
        }
    }
}