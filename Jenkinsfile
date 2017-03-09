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

    stage('Run tests') {
      steps {
        sh 'bash --login -c "bundle install --without development -j 4"'
        withEnv(['RAILS_ENV=test']) {
          sh 'bash --login -c "bundle exec rake db:create db:schema:load ci"'
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
}
