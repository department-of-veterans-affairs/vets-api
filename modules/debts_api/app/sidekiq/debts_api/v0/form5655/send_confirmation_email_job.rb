# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'
require 'sidekiq/attr_package'

module DebtsApi
  class V0::Form5655::SendConfirmationEmailJob
    include Sidekiq::Job

    FSR_STATS_KEY = 'api.form5655.send_confirmation_email'
    DIGITAL_DISPUTE_STATS_KEY = 'api.digital_dispute.send_confirmation_email'

    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |job, ex|
      args = job['args'][0]
      cache_key = args['cache_key']
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

      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    end

    def perform(args)
      submission_type = args['submission_type'] || 'fsr'
      cache_key = args['cache_key']
      pii = fetch_pii(cache_key, args)

      submissions_data = find_submissions(args['user_uuid'], submission_type)

      if submissions_data.blank?
        Rails.logger.warn(
          "DebtsApi::SendConfirmationEmailJob (#{submission_type}) - " \
          "No submissions found for user_uuid: #{args['user_uuid']}"
        )
        Sidekiq::AttrPackage.delete(cache_key) if cache_key
        return
      end

      send_vanotify_email(args['template_id'], pii, submissions_data, submission_type)
      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    rescue Sidekiq::AttrPackageError => e
      # Log AttrPackage errors as application logic errors (no retries)
      Rails.logger.error('V0::Form5655::SendConfirmationEmailJob', { error: e.message })
      raise ArgumentError, e.message
    rescue => e
      Rails.logger.error("DebtsApi::SendConfirmationEmailJob (#{submission_type}) - Error sending email: #{e.message}")
      raise e
    end

    private

    def send_vanotify_email(template_id, pii, submissions_data, submission_type)
      cache_key = Sidekiq::AttrPackage.create(
        email: pii[:email],
        personalisation: email_personalization_info(pii, submissions_data, submission_type)
      )
      DebtManagementCenter::VANotifyEmailJob.perform_async(
        nil, template_id, nil, { id_type: 'email', cache_key: }
      )
    end

    # Temporary fallback, after all pre-migration jobs have processed we will remove
    def fetch_pii(cache_key, args)
      if cache_key
        attributes = Sidekiq::AttrPackage.find(cache_key)
        return { email: attributes[:email], first_name: attributes[:first_name] } if attributes
      end

      { email: args['email'], first_name: args['first_name'] }
    end

    def email_personalization_info(pii, submissions_data, submission_type)
      confirmation_number = if submission_type == 'fsr'
                              submissions_data.map(&:id)
                            else
                              submissions_data.guid
                            end

      {
        'first_name' => pii[:first_name],
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
