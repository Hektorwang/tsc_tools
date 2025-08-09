pipeline {
    agent {
        docker {
            image 'openeuler/openeuler:22.03-lts-sp3'
            reuseNode true
            args '-v ${WORKSPACE}:/app'
        }
    }

    triggers {
        GenericTrigger(
            token: 'build-tsc_tools',
            causeString: 'Gitea PR Trigger',
            genericVariables: [
                [
                    key: 'PR_NUMBER',
                    value: '$.pull_request.number'
                ],
                [
                    key: 'PR_HEAD_REF',
                    value: '$.pull_request.head.ref'
                ],
                [
                    key: 'GIT_CLONE_URL',
                    value: '$.repository.clone_url'
                ]
            ]
        )
    }

    environment {
        TZ = 'Asia/Shanghai'
        DOCKER_HOST = 'unix:///var/run/docker.sock' 
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    stages {
        stage('Checkout PR Branch') {
            steps {
                script {
                    def prBranch = env.PR_HEAD_REF
                    def gitUrl = env.GIT_CLONE_URL

                    if (prBranch == null || gitUrl == null) {
                        error("无法获取 PR 分支或 Git URL。请检查 Jenkins 项目的通用 Webhook 配置。")
                    }

                    echo "Checking out PR branch: ${prBranch} from repository: ${gitUrl}"

                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${prBranch}"]],
                        userRemoteConfigs: [[
                            url: "${gitUrl}",
                            credentialsId: 'ec5d234f-f924-4852-ba3f-5bef1a04b38f'
                        ]],
                        extensions: []
                    ])
                }
            }
        }
        stage('Build') {
            steps {
                sh '''
                pwd;ls -l
                dnf install --assumeyes findutils bash
                sh -x build.sh
                '''
            }
        }
        stage('Archive Output') {
            steps {
                archiveArtifacts artifacts: 'release/tsc_tools-*.sh', fingerprint: true
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}