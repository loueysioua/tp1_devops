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

        stage('Image Scanning (Trivy)') {
            steps {
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        aquasec/trivy:latest image \\
                        --severity CRITICAL \\
                        --exit-code 0 \\
                        --no-progress \\
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
            steps {
                // Step 1: write the script via sh so $WORKSPACE is resolved by
                // the Jenkins shell — guarantees the file lands in the exact
                // directory that will be mounted (handles @2, @3 suffixes too)
                sh '''
                    printf '#!/bin/sh\nset -e\nterraform init\nterraform validate\nterraform plan -var="image_tag=$BUILD_NUMBER" -out=tfplan\nterraform apply -auto-approve tfplan\n' > "$WORKSPACE/tf-run.sh"
                    chmod +x "$WORKSPACE/tf-run.sh"
                    echo "Script written to: $WORKSPACE/tf-run.sh"
                    ls -la "$WORKSPACE/tf-run.sh"
                '''
                // Step 2: mount that exact workspace and run the script inside terraform container
                sh """
                    docker run --rm \\
                        --network host \\
                        --entrypoint sh \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v ${env.WORKSPACE}:/workspace \\
                        -w /workspace \\
                        hashicorp/terraform:1.5.7 \\
                        /workspace/tf-run.sh
                """
            }
        }

        stage('Verify & Health Check (Ansible)') {
            steps {
                sh """
                    docker run --rm \\
                        --network host \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v ${env.WORKSPACE}:/ansible \\
                        -w /ansible \\
                        cytopia/ansible:latest \\
                        ansible-playbook -i hosts.ini deploy.yml \\
                            --extra-vars "image_tag=${BUILD_NUMBER} image_name=${IMAGE_NAME}"
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    echo "Attente du démarrage..."
                    sleep 5
                    STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
                        --max-time 10 http://localhost:8081/health || echo "000")
                    echo "HTTP Status: ${STATUS}"
                    if [ "$STATUS" != "200" ]; then
                        echo "Smoke test FAILED"
                        exit 1
                    fi
                    echo "Smoke test OK"
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        failure {
            sh '''
                docker stop tf-web tf-db-service 2>/dev/null || true
                docker rm   tf-web tf-db-service 2>/dev/null || true
            '''
        }
    }
}