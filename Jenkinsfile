dev_branch = 'master'
staging_branch = 'master'
main_branch = 'master'

pipeline {
  environment {
    DOCKER_IMAGE = env.BUILD_TAG.replaceAll(/[%\/]/, '')

    // for PRs, BRANCH_NAME = PR-<ID>. for branches in the remote w/o a PR, BRANCH_NAME = <the name of the branch>
    // THE_BRANCH is a hack to normalize this value depending on if Jenkins "discovered" using "branch" or "pull-request"
    THE_BRANCH = "${env.CHANGE_BRANCH != null ? env.CHANGE_BRANCH : env.BRANCH_NAME}"

    CI = "true"
    RAILS_ENV = "test"
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

    stage('Build Docker Images'){
      steps {
        withCredentials([string(credentialsId: 'sidekiq-enterprise-license', variable: 'BUNDLE_ENTERPRISE__CONTRIBSYS__COM')]) {
          sh 'make ci-build'
        }
      }
    }

    stage('Setup Testing DB') {
      steps {
        sh 'make ci-db'
      }
    }

    stage('Lint') {
      steps {
        sh 'make ci-lint'
      }
    }

    stage('Security Scan') {
      steps {
        sh 'make ci-security'
      }
    }

    stage('Run tests') {
      steps {
        sh 'make ci-spec'
      }
      post {
        success {
          archiveArtifacts artifacts: "coverage/**"
          publishHTML(target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage', keepAll: true])
          junit 'log/*.xml'
        }
      }
    }

    stage('Run Danger Bot') {
      steps {
        withCredentials([string(credentialsId: 'danger-github-api-token',    variable: 'DANGER_GITHUB_API_TOKEN')]) {
          sh 'make danger'
        }
      }
    }

    stage('Review') {
      when { not { branch 'master' } }

      steps {
        build job: 'deploys/vets-review-instance-deploy', parameters: [
          stringParam(name: 'devops_branch', value: 'master'),
          stringParam(name: 'api_branch', value: env.THE_BRANCH),
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
        build job: 'deploys/vets-api-server-vagov-dev', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          booleanParam(name: 'migration_status', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false

        build job: 'deploys/vets-api-worker-vagov-dev', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          booleanParam(name: 'migration_status', value: false),
          stringParam(name: 'ref', value: commit),
        ], wait: false
      }
    }

    stage('Deploy staging') {
      when { branch staging_branch }

      steps {
        build job: 'deploys/vets-api-server-vagov-staging', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          booleanParam(name: 'migration_status', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false

        build job: 'deploys/vets-api-worker-vagov-staging', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          booleanParam(name: 'migration_status', value: false),
          stringParam(name: 'ref', value: commit),
        ], wait: false
      }
    }
  }
  post {
    always {
      sh 'make ci-down'
      deleteDir() /* clean up our workspace */
    }
    failure {
      when { branch 'master' }

      slackSend message: "Failed vets-api CI on branch: `${env.THE_BRANCH}`! ${env.RUN_DISPLAY_URL}".stripMargin(),
      color: 'danger',
      failOnError: true
    }
  }
}
