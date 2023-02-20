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

    stage('Scheudle Review Instance Creation') {
      when { not { branch 'master' } }

      steps {
        build job: 'deploys/vets-review-instance-deploy', parameters: [
          stringParam(name: 'devops_branch', value: 'master'),
          stringParam(name: 'api_branch', value: env.THE_BRANCH),
          stringParam(name: 'web_branch', value: env.THE_BRANCH),
          stringParam(name: 'content_branch', value: 'master'),
          stringParam(name: 'source_repo', value: 'vets-api'),
        ], wait: false
      }
    }

    stage('Build AMI') {
      when { anyOf { branch staging_branch; branch main_branch } }

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

    stage('Deploy staging') {
      when { branch staging_branch }

      steps {
        build job: 'deploys/vets-api-server-vagov-staging', parameters: [
          booleanParam(name: 'notify_slack', value: true),
          booleanParam(name: 'migration_status', value: true),
          stringParam(name: 'ref', value: commit),
        ], wait: false

      }
    }
  }
  post {
    always {
      sh 'env=$RAILS_ENV make down'
      deleteDir() /* clean up our workspace */
    }
    failure {
      script {
        if (env.BRANCH_NAME == 'master') {
          slackSend message: "Failed vets-api CI on branch: `${env.THE_BRANCH}`! ${env.RUN_DISPLAY_URL}".stripMargin(),
          color: 'danger',
          failOnError: true
        }
      }
    }
  }
}
