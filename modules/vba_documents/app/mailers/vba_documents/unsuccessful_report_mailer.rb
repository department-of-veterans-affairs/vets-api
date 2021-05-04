# frozen_string_literal: true

require 'vba_documents/deployment'

module VBADocuments
  class UnsuccessfulReportMailer < ApplicationMailer
    def self.fetch_recipients
      env = VBADocuments::Deployment.environment
      env = 'prod' if env.eql?(:unknown_environment)
      # the above shouldn't get hit, but if an environment becomes undetectable we will send that env to everyone
      # and tag it as 'unknown_environment' to motivate a quick repair.
      hash = YAML.load_file("#{__dir__}/unsuccessful_report_recipients.yml")
      env_hash = hash[env.to_s].nil? ? [] : hash[env.to_s]
      env_hash + hash['common']
    end

    RECIPIENTS = fetch_recipients.freeze

    def build(consumer_totals, pending_submissions, unsuccessful_submissions, date_from, date_to)
      @consumer_totals = consumer_totals
      @pending_submissions = pending_submissions
      @unsuccessful_submissions = unsuccessful_submissions
      @date_from = date_from
      @date_to = date_to
      @environment = VBADocuments::Deployment.environment

      path = VBADocuments::Engine.root.join(
        'app',
        'views',
        'vba_documents',
        'unsuccessful_report_mailer',
        'unsuccessful_report.html.erb'
      )
      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: "Benefits Intake Unsuccessful Submission Report for #{@environment}",
        body: body
      )
    end
  end
end
