def notify(message, color='good') {
    if (notify_slack.toBoolean()) {
        slackSend message: message,
                  color: color,
                  failOnError: true
    }
}

pipeline {
  agent label:''
  stages {
    stage('Notify Slack') {
      notify """Deploying `${application}` to `${environment}`.
               |${currentBuild.rawBuild.getCauses()[0].getShortDescription()}
               |${currentBuild.getAbsoluteUrl()}""".stripMargin()
    }

    stage('Checkout Code') {
      checkout scm: [$class: 'GitSCM', branches: [[name: '*/master']],
               extensions: [[$class: 'SubmoduleOption', recursiveSubmodules: true]],
               userRemoteConfigs: [[url: 'git@github.com:department-of-veterans-affairs/devops.git']]]
    }

    stage('Create virtualenv') {
      dir('ansible') {
        sh 'virtualenv venv'
        sh 'venv/bin/pip install -r requirements.txt'
      }
    }

    stage('Run Ansible deploy') {
      dir('ansible') {
        sh  "bash -c 'source venv/bin/activate && ansible-playbook " +
            "-e env=${environment} " +
            "-e app_name=${application} " +
            "-e force_ami=${force_ami} " +
            "-e git_version=${branch} " +
            "-i inventory " +
            "aws-deploy-app.yml'"
      }
    }
  }

  notifications {
    success {
      notify """Successfully deployed `${application}` to `${environment}`.
               |Took ${currentBuild.rawBuild.getDurationString()}""".stripMargin()
    }
    failure {
      notify """Failed to deploy `${application}` to `${environment}`!
               |${currentBuild.getAbsoluteUrl()}console""".stripMargin(), 'danger'
    }
  }
}
