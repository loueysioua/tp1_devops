pipeline {
    // Exécute le pipeline sur n'importe quel agent Jenkins disponible
    agent any

    environment {
        IMAGE_NAME = "loueysioua/mon-app-devops"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source depuis Git...'
                // Si tu as configuré ton pipeline depuis l'interface "Pipeline from SCM",
                // Jenkins fera le checkout automatiquement. Sinon, utilise cette commande :
                checkout scm
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Exécution des tests unitaires...'
                // Jenkins arrête AUTOMATIQUEMENT le pipeline si une commande "sh" échoue (code de retour != 0).
                // Adapte cette ligne selon le langage de ton app (ex: npm test, pytest, go test)
                sh 'python -m unittest discover'
            }
        }

        stage('Docker Build') {
            steps {
                echo "Construction de l'image Docker avec le tag ${BUILD_NUMBER}..."
                // On tague l'image avec le numéro de build Jenkins ET avec 'latest'
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                sh "docker build -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Docker Push') {
            steps {
                echo 'Connexion à Docker Hub et publication...'
                // withCredentials masque le mot de passe dans les logs Jenkins
                // 'docker-hub-credentials' est l'ID que tu as créé à l'Étape 1
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials',
                                                 passwordVariable: 'DOCKER_PASSWORD',
                                                 usernameVariable: 'DOCKER_USERNAME')]) {

                    // Connexion sécurisée via l'entrée standard (stdin)
                    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'

                    // Si on arrive ici, c'est que les tests ont réussi (contrainte respectée)
                    sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }
    }

    // Le bloc post s'exécute toujours à la fin, peu importe le résultat
    post {
        always {
            echo 'Nettoyage : Déconnexion de Docker Hub...'
            sh 'docker logout'
        }
    }
}