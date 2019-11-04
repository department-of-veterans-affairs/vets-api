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
        withCredentials([
          string(credentialsId: 'sidekiq-enterprise-license', variable: 'BUNDLE_ENTERPRISE__CONTRIBSYS__COM'),
          string(credentialsId: 'danger-github-api-token',    variable: 'DANGER_GITHUB_API_TOKEN')
        ]) {
          withEnv(['RAILS_ENV=test', 'CI=true']) {
            sh 'docker-compose -f docker-compose.test.yml build'
          }
        }
      }
    }

    stage('Setup Testing DB') {
      steps {
        sh 'make test_db'
      }
    }

    stage('Lint') {
      steps {
        sh 'make lint_ci'
      }
    }

    stage('Security Scan') {
      steps {
        sh 'make security_ci'
      }
    }

    // stage('Run tests') {
    //   steps {
    //     sh 'make spec_ci'
    //   }
    //   post {
    //     success {
    //       archiveArtifacts artifacts: "coverage/**"
    //       publishHTML(target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage', keepAll: true])
    //       junit 'log/*.xml'
    //     }
    //   }
    // }

    stage('Danger Bot'){
      steps {
        sh 'make danger'
      }
    }
  }

  post {
    always {
      sh 'make clean'
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
