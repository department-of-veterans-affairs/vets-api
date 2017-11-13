pipeline {
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
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'make ci'
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

    stage('Deploy dev and staging') {
      when { branch 'brd-deploy' }

      steps {
        build job: 'builds/vets-api', parameters: [
          booleanParam('notify_slack', true),
          stringParam(name: 'ref', env.GIT_COMMIT),
          booleanParam('release', false),
        ], wait: true

        build job: 'deploys/vets-api-server-dev-brd', parameters: [
          booleanParam('notify_slack', true),
          stringParam(name: 'ref', env.GIT_COMMIT),
        ], wait: false

        build job: 'deploys/vets-api-worker-dev-brd', parameters: [
          booleanParam('notify_slack', true),
          stringParam(name: 'ref', env.GIT_COMMIT),
        ], wait: false
      }
    }
  }
  post {
        always {
            archive "coverage/**"
            publishHTML(target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage', keepAll: true])
            junit 'log/*.xml'
            sh 'make clean'
            deleteDir() /* clean up our workspace */
        }
  }
}
