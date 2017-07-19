pipeline {
  agent {
    label 'vets-api-linting'
  }
  stages {
    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Prepare workspace') {
      steps {
        sh 'mkdir coverage'
      }
    }

    stage('Run tests') {
      steps {
        withEnv(['RAILS_ENV=test', 'CI=true']) {
          sh 'docker-compose run vets-api bash --login -c "bundle exec rake db:create db:schema:load ci"'
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
  }
  post {
        always {
            archive "coverage/**"
            publishHTML(target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage', keepAll: true])
            junit 'log/*.xml'
            deleteDir() /* clean up our workspace */
        }
  }
}
