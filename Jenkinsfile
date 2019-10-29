dev_branch = 'master'
staging_branch = 'master'
main_branch = 'master'

pipeline {
  environment {
    DOCKER_IMAGE = env.BUILD_TAG.replaceAll(/[%\/]/, '')

    // for PRs, BRANCH_NAME = PR-<ID>. for branches in the remote w/o a PR, BRANCH_NAME = <the name of the branch>
    // THE_BRANCH is a hack to normalize this value depending on if Jenkins "discovered" using "branch" or "pull-request"
    THE_BRANCH = "${env.CHANGE_BRANCH != null ? env.CHANGE_BRANCH : env.BRANCH_NAME}"
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

    // stage('Prepare Docker Env Variables') {
    //   steps {
    //     sh 'rm -f .env'
    //     sh 'touch .env'
    //     sh 'echo "BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$BUNDLE_ENTERPRISE__CONTRIBSYS__COM" >> .env'
    //     sh 'echo "DANGER_GITHUB_API_TOKEN=$DANGER_GITHUB_API_TOKEN" >> .env'
    //     sh 'echo "DANGER_GITHUB_API_TOKEN=$DANGER_GITHUB_API_TOKEN" >> .env'
    //   }
    // }

    stage('Setup Testing DB') {
      steps {
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'make test_db'
        }
      }
    }

    stage('Lint') {
      steps {
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'make lint_ci'
        }
      }
    }

    stage('Security Scan') {
      steps {
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'make security_ci'
        }
      }
    }

    stage('Run tests') {
      steps {
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'make spec_ci'
          //sh 'docker-compose run -e BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$BUNDLE_ENTERPRISE__CONTRIBSYS__COM -e RAILS_ENV=test -e CI=true vets-api bash -c "bin/rails lint"'
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

    stage('Danger Bot'){
      steps {
        withCredentials([
          string(credentialsId: 'danger-github-api-token',    variable: 'DANGER_GITHUB_API_TOKEN')
        ]) {
          withEnv(['RAILS_ENV=test', 'CI=true']) {
            sh 'make danger'
          }
        }
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
