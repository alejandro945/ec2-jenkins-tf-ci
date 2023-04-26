pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                checkout scmGit(
                branches: [[name: 'main']],
                userRemoteConfigs: [[url: 'https://github.com/Issblann/Teclado']])
                sh 'sshpass -p \"Alejo8#\" scp -r $(pwd)/* adminuser@20.163.219.26:/var/www/html/'
            }
        }
    }
}