dev_branch = 'master'
staging_branch = 'master'
main_branch = 'master'

pipeline {
  environment {
    DOCKER_IMAGE = env.BUILD_TAG.replaceAll(/[%\/]/, '')
  }

  options {
    buildDiscarder(logRotator(daysToKeepStr: '60'))
  }

  agent {
    label 'vetsgov-general-purpose'
  }

  stages {
    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Run tests') {
      steps {
        withCredentials([string(credentialsId: 'sidekiq-enterprise-license', variable: 'BUNDLE_ENTERPRISE__CONTRIBSYS__COM')]) {
          withEnv(['RAILS_ENV=test', 'CI=true']) {
            sh 'make ci'
          }
        }
      }
      post {
        success {
          archiveArtifacts artifacts: "coverage/**"
          publishHTML(target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage', keepAll: true])
          junit 'log/*.xml'
        }
      }
    }

    stage('Review') {
      when {
        expression {
          !['master', 'production'].contains(env.BRANCH_NAME)
        }
      }

      steps {
        build job: 'deploys/vets-review-instance-deploy', parameters: [
          stringParam(name: 'devops_branch', value: 'master'),
          stringParam(name: 'api_branch', value: env.BRANCH_NAME),
          stringParam(name: 'web_branch', value: 'master'),
          stringParam(name: 'source_repo', value: 'vets-api'),
        ], wait: false
      }
    }

    stage('Build AMI') {
      when { anyOf { branch dev_branch; branch staging_branch; branch main_branch } }

      steps {
        // hack to get the commit hash, some plugin is swallowing git variables and I can't figure out which one
        script {
          commit = sh(returnStdout: true, script: "git rev-parse HEAD").trim()
        }

        build job: 'builds/vets-api', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          stringParam(name: 'ref', value: commit),
          booleanParam(name: 'release', value: false),
        ], wait: true
      }
    }

    stage('Deploy dev') {
      when { branch dev_branch }

      steps {
        build job: 'deploys/vets-api-server-dev', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false

        build job: 'deploys/vets-api-worker-dev', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false
      }
    }

    stage('Deploy staging') {
      when { branch staging_branch }

      steps {
        build job: 'deploys/vets-api-server-staging', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false

        build job: 'deploys/vets-api-worker-staging', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false
      }
    }
  }
  post {
    always {
      sh 'make clean'
      deleteDir() /* clean up our workspace */
    }
    failure {
      script {
        if (env.BRANCH_NAME == 'master') {
          slackSend message: "Failed vets-api CI on branch: `${env.BRANCH_NAME}`! ${env.RUN_DISPLAY_URL}".stripMargin(),
          color: 'danger',
          failOnError: true
        }
      }
    }
  }
}
