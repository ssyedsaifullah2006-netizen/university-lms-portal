pipeline {
    agent any

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        choice(
            name: 'RELEASE_MODE',
            choices: ['stable', 'faulty'],
            description: 'Select faulty only to demonstrate automatic rollback'
        )
    }

    environment {
        IMAGE_REPO = 'syedsaifu/university-lms-portal'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.RELEASE_TAG = "build-${env.BUILD_NUMBER}"
                }
                bat 'git log -1 --oneline'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    docker build --pull --build-arg RELEASE_MODE=%RELEASE_MODE% -t %IMAGE_REPO%:%RELEASE_TAG% .
                '''
            }
        }

        stage('Test Docker Image') {
            steps {
                script {
                    bat(
                        script: 'docker rm -f lms-ci-test >NUL 2>&1',
                        returnStatus: true
                    )

                    bat '''
                        docker run -d --name lms-ci-test -p 18082:80 %IMAGE_REPO%:%RELEASE_TAG%
                    '''

                    try {
                        bat '''
                            powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Sleep -Seconds 3; $r=Invoke-WebRequest -Uri 'http://localhost:18082/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'University Learning Management Portal') { exit 1 }"
                        '''
                    } finally {
                        bat(
                            script: 'docker rm -f lms-ci-test >NUL 2>&1',
                            returnStatus: true
                        )
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_PASS'
                    )
                ]) {
                    bat '''
                        powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:DH_PASS | docker login -u $env:DH_USER --password-stdin"
                        if errorlevel 1 exit /b 1
                        docker push %IMAGE_REPO%:%RELEASE_TAG%
                        if errorlevel 1 exit /b 1
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy and Health Check') {
            steps {
                script {
                    withCredentials([
                        file(
                            credentialsId: 'kuberconfig',
                            variable: 'KUBECONFIG'
                        )
                    ]) {
                        bat '''
                            powershell -NoProfile -ExecutionPolicy Bypass -Command "$content=Get-Content deployment.yaml -Raw; $content=$content.Replace('IMAGE_TAG',$env:RELEASE_TAG); Set-Content -Path deployment-rendered.yaml -Value $content -Encoding ascii"
                            if errorlevel 1 exit /b 1

                            kubectl apply -f service.yaml
                            if errorlevel 1 exit /b 1

                            kubectl apply -f deployment-rendered.yaml
                            if errorlevel 1 exit /b 1
                        '''

                        try {
                            bat '''
                                kubectl rollout status deployment/university-lms-portal --timeout=90s
                            '''
                        } catch (err) {
                            echo 'ROLLOUT FAILED. Rolling back automatically.'

                            bat '''
                                kubectl rollout undo deployment/university-lms-portal
                                if errorlevel 1 exit /b 1

                                kubectl rollout status deployment/university-lms-portal --timeout=120s
                                if errorlevel 1 exit /b 1

                                kubectl wait --for=condition=available deployment/university-lms-portal --timeout=60s
                                if errorlevel 1 exit /b 1

                                kubectl get deployment university-lms-portal
                                kubectl get pods -o wide
                            '''

                            error('New release failed; previous release restored.')
                        }

                        bat '''
                            kubectl wait --for=condition=available deployment/university-lms-portal --timeout=60s
                            if errorlevel 1 exit /b 1

                            kubectl get deployment university-lms-portal
                            kubectl get pods -o wide
                            kubectl get service university-lms-service
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
        }
        failure {
            echo 'Release failed. Inspect the console for rollout and rollback results.'
        }
    }
}