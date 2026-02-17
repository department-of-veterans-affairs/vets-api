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
      submission_type = args['submission_type'] || 'fsr' # TODO: make this file not fsr specific
      submissions_data = find_submissions(args['user_uuid'], submission_type)
      
      if submissions_data.blank?
        Rails.logger.warn(
          "DebtsApi::SendConfirmationEmailJob (#{submission_type}) - " \
          "No submissions found for user_uuid: #{args['user_uuid']}"
        )
        Sidekiq::AttrPackage.delete(args['cache_key']) if args['cache_key']
        return
      end
  
      should_use_cache = !args['user_pii'].present?
      is_retry = args['cache_key'].present?
      pii = resolve_pii(args, should_use_cache, is_retry)

      send_vanotify_email(args['template_id'], pii, should_use_cache, submissions_data, submission_type)
    rescue Sidekiq::AttrPackageError => e
      # Log AttrPackage errors as application logic errors (no retries)
      Rails.logger.error('V0::Form5655::SendConfirmationEmailJob', { error: e.message })
      raise ArgumentError, e.message
    rescue => e
      Rails.logger.error("DebtsApi::SendConfirmationEmailJob (#{submission_type}) - Error sending email: #{e.message}")
      raise e
    end

    private

    def send_vanotify_email(template_id, pii, should_use_cache, submissions_data, submission_type)
      personalisation = email_personalization_info(pii, submissions_data, submission_type)
      cache_key = unless pii.present?
        Sidekiq::AttrPackage.create(
          email: pii&.dig(:email),
          personalisation: personalisation
        )
      end
      identifier = should_use_cache ? pii&.dig(:email) : nil
      options = should_use_cache ? { id_type: 'email', cache_key: } : {}

      DebtManagementCenter::VANotifyEmailJob.perform_async(
        identifier, template_id, personalisation, options
      )
    end
    
    def fetch_pii_from_cache(cache_key)
      attributes = Sidekiq::AttrPackage.find(cache_key)
      { email: attributes[:email], first_name: attributes[:first_name] } if attributes
    end

    def resolve_pii(args, should_use_cache, is_retry)
      (is_retry && should_use_cache) ? fetch_pii_from_cache(args['cache_key']) : args['user_pii']
    end

    def email_personalization_info(pii, submissions_data, submission_type)
      confirmation_number = if submission_type == 'fsr'
                              submissions_data.map(&:id)
                            else
                              submissions_data.guid
                            end

      {
        'first_name' => pii&.dig(:first_name),
        'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
        'confirmation_number' => confirmation_number
      }
    end

    def find_submissions(user_uuid, submission_type)
      case submission_type
      when 'digital_dispute'
        DebtsApi::V0::DigitalDisputeSubmission.where(user_uuid:, state: 1)
                                              .order(created_at: :desc).first
      else
        DebtsApi::V0::Form5655Submission.where(user_uuid:, state: 1)
      end
    end
  end
end
