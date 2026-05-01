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
    }

    post {
        always {
            sh 'docker logout'
        }
    }
}