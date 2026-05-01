pipeline {
    agent any

    environment {
        IMAGE_NAME = "loueysioua/mon-app-devops"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source depuis Git...'
                checkout scm
            }
        }

        stage('Build & Tests Unitaires') {
            agent {
                docker {
                    image 'python:3.11-alpine'
                    reuseNode true
                }
            }
            steps {
                sh 'pip install --no-cache-dir -r requirements.txt'
                sh 'python -m unittest discover'
            }
        }

        stage('Analyse Statique (SonarQube)') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    // The Docker plugin reads the network name from this env var
                    args '--network tp_docker_sioua_louey_app-network'
                    reuseNode true
                }
            }
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'sonar-scanner'
                }
            }
        }
 
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Image Scanning (Trivy)') {
            steps {
                echo '🛡️  Scan de vulnérabilités avec Trivy...'
                sh """
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity CRITICAL \
                        --exit-code 0 \
                        --no-progress \
                        ${IMAGE_NAME}:${BUILD_NUMBER}
                """
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials',
                                                 passwordVariable: 'DOCKER_PASSWORD',
                                                 usernameVariable: 'DOCKER_USERNAME')]) {
                    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'
                    sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Infrastructure Provisioning (Terraform)') {
            agent {
                docker {
                    image 'hashicorp/terraform:latest'
                    reuseNode true
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                sh '''
                    apk add --no-cache docker-cli
                    terraform init
                    terraform validate
                    terraform plan -out=tfplan
                    terraform apply -auto-approve tfplan
                '''
            }
        }

        stage('Configuration & Deploy (Ansible)') {
            agent {
                docker {
                    image 'willhallonline/ansible:latest'
                    reuseNode true
                    args '--network host -u root'
                }
            }
            steps {
                withEnv(["K8S_AUTH_KUBECONFIG=${WORKSPACE}/kubeconfig"]) {
                    sh """
                        pip install kubernetes
                        ansible-playbook -i hosts.ini deploy.yml \
                            --extra-vars "image_tag=latest image_name=${IMAGE_NAME} k8s_namespace=production"
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    echo "Attente du démarrage des pods..."
                    sleep 10
                    STATUS=$(curl -H "Host: mon-app.local" -o /dev/null -s -w "%{http_code}" --max-time 10 http://localhost:8081 || echo "000")
                    echo "HTTP Status: ${STATUS}"
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout'
        }
    }
}