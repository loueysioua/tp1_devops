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
                script {
                    // Write the build number directly into the script using Groovy interpolation
                    // Single-quoted sh blocks don't expand $BUILD_NUMBER inside the container
                    sh """
                        printf '#!/bin/sh\\nset -e\\ncd terraform\\nterraform init\\nterraform validate\\nterraform plan -var="image_tag=${BUILD_NUMBER}" -out=tfplan\\nterraform apply -auto-approve tfplan\\n' > "\$WORKSPACE/tf-run.sh"
                        chmod +x "\$WORKSPACE/tf-run.sh"
                        echo "Script content:"; cat "\$WORKSPACE/tf-run.sh"
                    """

                    // Get the Jenkins container ID so we can share its volumes
                    def jenkinsId = sh(
                        returnStdout: true,
                        script: "docker ps -qf 'name=jenkins'"
                    ).trim()

                    echo "Jenkins container ID: ${jenkinsId}"

                    // --volumes-from mounts all Jenkins volumes (including jenkins-data)
                    // into the terraform container — workspace path is identical
                    sh """
                        docker run --rm \\
                            --network host \\
                            --entrypoint sh \\
                            --volumes-from ${jenkinsId} \\
                            -v /var/run/docker.sock:/var/run/docker.sock \\
                            -w ${env.WORKSPACE} \\
                            hashicorp/terraform:1.5.7 \\
                            ${env.WORKSPACE}/tf-run.sh
                    """
                }
            }
        }

        stage('Verify & Health Check (Ansible)') {
            steps {
                script {
                    def jenkinsId = sh(
                        returnStdout: true,
                        script: "docker ps -qf 'name=jenkins'"
                    ).trim()

                    sh """
                        docker run --rm \\
                            --network host \\
                            --volumes-from ${jenkinsId} \\
                            -v /var/run/docker.sock:/var/run/docker.sock \\
                            -w ${env.WORKSPACE}/ansible \\
                            cytopia/ansible:latest \\
                            ansible-playbook -i hosts.ini deploy.yml \\
                                --extra-vars "image_tag=${BUILD_NUMBER} image_name=${IMAGE_NAME}"
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                // curl runs inside a container on the same network as tf-web
                // "tf-web:5000" resolves via Docker DNS on terraform-app-network
                sh """
                    echo "Attente du démarrage..."
                    sleep 5
                    STATUS=\$(docker run --rm \\
                        --network terraform-app-network \\
                        curlimages/curl:latest \\
                        -o /dev/null -s -w "%{http_code}" \\
                        --max-time 10 \\
                        http://tf-web:5000/health || echo "000")
                    echo "HTTP Status: \${STATUS}"
                    if [ "\${STATUS}" != "200" ]; then
                        echo "Smoke test FAILED"
                        exit 1
                    fi
                    echo "Smoke test OK"
                """
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