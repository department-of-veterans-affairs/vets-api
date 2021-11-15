# frozen_string_literal: true

require 'vba_documents/deployment'

module VBADocuments
  class MonthlyReportMailer < ApplicationMailer
    def self.fetch_recipients
      env = VBADocuments::Deployment.environment
      env = 'prod' if env.eql?(:unknown_environment)
      # the above shouldn't get hit, but if an environment becomes undetectable we will send that env to everyone
      # and tag it as 'unknown_environment' to motivate a quick repair.
      hash = YAML.load_file("#{__dir__}/monthly_report_recipients.yml")
      env_hash = hash[env.to_s].nil? ? [] : hash[env.to_s]
      env_hash + hash['common']
    end

    RECIPIENTS = fetch_recipients.freeze

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/ParameterLists
    def build(monthly_totals, summary, still_processing, still_success,
              monthly_grouping, rolling_elapsed_times, last_month_start, last_month_end)
      @monthly_totals = monthly_totals
      @summary_totals = summary
      @last_month_still_processing = still_processing
      @last_month_still_success = still_success
      @monthly_grouping = monthly_grouping
      @last_month_start = last_month_start
      @last_month_end = last_month_end
      @rolling_elapsed_times = rolling_elapsed_times
      @environment = VBADocuments::Deployment.environment

      path = VBADocuments::Engine.root.join(
        'app',
        'views',
        'vba_documents',
        'monthly_report_mailer',
        'monthly_report.html.erb'
      )
      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: "Monthly Benefits Intake Submission Report for #{@environment}",
        body: body
      )
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/ParameterLists
  end
end
