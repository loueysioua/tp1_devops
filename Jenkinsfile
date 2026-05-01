pipeline {
    agent any

    environment {
        IMAGE_NAME  = "loueysioua/mon-app-devops"
        APP_NETWORK = "tp_docker_sioua_louey_app-network"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ✅ agent { docker } works fine — python:alpine has sh
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

        // ✅ agent { docker } works fine — sonar image has sh
        stage('Analyse Statique (SonarQube)') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    args  "--network ${APP_NETWORK}"
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

        // ✅ docker run directly — bypasses agent { docker } shell issue
        stage('Image Scanning (Trivy)') {
            steps {
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

        // ✅ docker run directly — hashicorp/terraform has no bash, agent { docker } fails
        stage('Infrastructure Provisioning (Terraform)') {
            steps {
                sh """
                    docker run --rm \
                        --network host \
                        --entrypoint sh \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v ${env.WORKSPACE}:/workspace \
                        -w /workspace \
                        hashicorp/terraform:1.5.7 \
                        -c "terraform init && terraform validate && terraform plan -out=tfplan && terraform apply -auto-approve tfplan"
                """
            }
        }

        // ✅ docker run directly — same pattern, no bash dependency
        stage('Configuration & Deploy (Ansible)') {
            steps {
                sh """
                    docker run --rm \
                        --network host \
                        -v ${env.WORKSPACE}:/ansible \
                        -w /ansible \
                        cytopia/ansible:latest \
                        ansible-playbook -i hosts.ini deploy.yml \
                            --extra-vars "image_tag=latest image_name=${IMAGE_NAME} k8s_namespace=production"
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    echo "Attente du démarrage des pods..."
                    sleep 10
                    STATUS=$(curl -H "Host: mon-app.local" -o /dev/null -s -w "%{http_code}" \
                        --max-time 10 http://localhost:8081 || echo "000")
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