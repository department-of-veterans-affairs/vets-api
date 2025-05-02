# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::SendConfirmationEmailJob
    include Sidekiq::Job

    sidekiq_retries_exhausted do |job, ex|
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      user_uuid = job['args'][0]['user_uuid']

      Rails.logger.error <<~LOG
        V0::Form5655::SendConfirmationEmailJob retries exhausted:
        user_id: #{user_uuid}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(args)
      form_submissions = submissions(args['user_uuid'])
      if form_submissions.blank?
        Rails.logger.warn(
          "DebtsApi::SendConfirmationEmailJob - No submissions found for user_uuid: #{args['user_uuid']}"
        )
        return
      end

      DebtManagementCenter::VANotifyEmailJob.perform_async(
        args['email'], args['template_id'], email_personalization_info(args, form_submissions), { id_type: 'email' }
      )
    rescue StandardError => e
      Rails.logger.error("DebtsApi::SendConfirmationEmailJob - Error sending email: #{e.message}")
      raise e
    end

    private

    def email_personalization_info(args, form_submissions)
      confirmation_numbers = form_submissions.map(&:id)
      {
        'first_name' => args['first_name'],
        'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
        'confirmation_number' => confirmation_numbers
      }
    end

    def submissions(user_uuid)
      DebtsApi::V0::Form5655Submission.where(user_uuid:, state: 1)
    end
  end
end
