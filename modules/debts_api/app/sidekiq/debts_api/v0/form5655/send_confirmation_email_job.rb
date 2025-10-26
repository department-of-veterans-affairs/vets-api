# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'
require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  class V0::Form5655::SendConfirmationEmailJob
    include Sidekiq::Job

    FSR_STATS_KEY = 'api.form5655.send_confirmation_email'
    DIGITAL_DISPUTE_STATS_KEY = 'api.digital_dispute.send_confirmation_email'

    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |job, ex|
      args = job['args'][0]
      submission_type = args['submission_type'] || 'fsr'
      stats_key = if submission_type == 'fsr'
                    FSR_STATS_KEY
                  else
                    DIGITAL_DISPUTE_STATS_KEY
                  end

      StatsD.increment("#{stats_key}.retries_exhausted")
      user_uuid = args['user_uuid']

      Rails.logger.error <<~LOG
        V0::Form5655::SendConfirmationEmailJob (#{submission_type}) retries exhausted:
        user_id: #{user_uuid}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(args)
      submission_type = args['submission_type'] || 'fsr'
      submissions_data = find_submissions(args['user_uuid'], submission_type)

      if submissions_data.blank?
        Rails.logger.warn(
          "DebtsApi::SendConfirmationEmailJob (#{submission_type}) - " \
          "No submissions found for user_uuid: #{args['user_uuid']}"
        )
        return
      end

      DebtManagementCenter::VANotifyEmailJob.perform_async(
        args['email'], args['template_id'], email_personalization_info(args, submissions_data,
                                                                       submission_type), { id_type: 'email' }
      )
    rescue => e
      Rails.logger.error("DebtsApi::SendConfirmationEmailJob (#{submission_type}) - Error sending email: #{e.message}")
      raise e
    end

    private

    def email_personalization_info(args, submissions_data, submission_type)
      confirmation_number = if submission_type == 'fsr'
                              submissions_data.map(&:id)
                            else
                              submissions_data.id
                            end

      {
        'first_name' => args['first_name'],
        'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
        'confirmation_number' => confirmation_number
      }
    end

    def find_submissions(user_uuid, submission_type)
      case submission_type
      when 'digital_dispute'
        # Fix: Add explicit ordering to get most recent submission
        DebtsApi::V0::DigitalDisputeSubmission.where(user_uuid:, state: 1)
                                              .order(created_at: :desc).first
      else
        DebtsApi::V0::Form5655Submission.where(user_uuid:, state: 1)
      end
    end
  end
end
