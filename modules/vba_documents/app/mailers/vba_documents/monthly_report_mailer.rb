# frozen_string_literal: true

require 'vba_documents/deployment'

module VBADocuments
  class MonthlyReportMailer < ApplicationMailer
    def self.fetch_recipients
      env = VBADocuments::Deployment.environment
      env = 'prod' if env.eql?(:unknown_environment)
      # the above shouldn't get hit, but if an environment becomes undetectable we will send that env to everyone
      # and tag it as 'unknown_environment' to motivate a quick repair.
      recipients = YAML.load_file("#{__dir__}/monthly_report_recipients.yml")

      recipients_for_current_env = recipients[env.to_s] || []
      recipients_for_all_envs = recipients['common'] || []

      if Settings.vba_documents.slack.enabled
        slack_alert_email = Settings.vba_documents.slack.default_alert_email
        (recipients_for_current_env + recipients_for_all_envs).uniq.append(slack_alert_email).compact
      else
        (recipients_for_current_env + recipients_for_all_envs).uniq
      end
    end

    RECIPIENTS = fetch_recipients.freeze

    def build(stats)
      sorted_stats = stats.sort_by { |h| [-h[:year], -h[:month]] }

      @report_month = Date::MONTHNAMES[sorted_stats[0].month]
      @report_year = sorted_stats[0].year.to_s
      @stats = sorted_stats
      @environment = VBADocuments::Deployment.environment

      path = VBADocuments::Engine.root.join('app', 'views', 'vba_documents',
                                            'monthly_report_mailer', 'monthly_report.html.erb')
      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: "Monthly Benefits Intake Submission Report for #{@environment}",
        body:
      )
    end
  end
end
