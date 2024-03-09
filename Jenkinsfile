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

    stage('Schedule Review Instance Creation') {
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
  }
  post {
    always {
      sh 'env=$RAILS_ENV make down'
      deleteDir() /* clean up our workspace */
    }
  }
}
