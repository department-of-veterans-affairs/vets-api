# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/claim_logger'
require 'sidekiq/monitored_worker'
require 'sentry_logging'

module ClaimsApi
  class ServiceBase
    include Sidekiq::Job
    include Sidekiq::MonitoredWorker
    include SentryLogging

    RETRY_STATUS_CODES = %w[500 502 503 504].freeze
    NO_RETRY_ERROR_CODES = ['form526.submit.noRetryError', 'form526.InProcess'].freeze

    LOG_TAG = 'claims_api_sidekiq_service_base'

    sidekiq_retries_exhausted do |message|
      ClaimsApi::Logger.log('claims_api_retries_exhausted',
                            record_id: message['args']&.first,
                            detail: "Job retries exhausted for #{message['class']}",
                            error: message['error_message'])

      classes = %w[ClaimsApi::V2::DisabilityCompensationPdfGenerator
                   ClaimApi::V2::DisabilityCompensationDockerContainerUpload
                   ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader].freeze

      claim_id = message&.dig('args', 0)

      if message['class'].present? && classes.include?(message['class']) && claim_id.present?
        claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)
        claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      end
    end

    def retry_limits_for_notification
      [11]
    end

    protected

    def slack_alert_on_failure(job_name, msg)
      notify_on_failure(
        job_name,
        msg
      )
    end

    def notify_on_failure(job_name, notification_message)
      slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                             channel: '#api-benefits-claims-alerts',
                                             username: "Failed #{job_name}")
      slack_client.notify(notification_message)
    end

    def set_state_for_submission(submission, state)
      submission.status = state
      submission.save!
    end

    def preserve_original_form_data(form_data)
      form_data.deep_dup.freeze
    end

    def set_errored_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::ERRORED)
    end

    def set_established_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
    end

    def clear_evss_response_for_claim(auto_claim)
      auto_claim.evss_response = nil
      save_auto_claim!(auto_claim, auto_claim.status)
    end

    def set_pending_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::PENDING)
    end

    def save_auto_claim!(auto_claim, status)
      auto_claim.status = status
      auto_claim.validation_method = ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
      auto_claim.save!
    end

    def set_evss_response(auto_claim, error)
      auto_claim.evss_response ||= []
      errors_to_add = []

      if error_responds_to_original_body?(error)
        if error&.original_body.present?
          errors_to_add.concat(error.original_body)
        else
          # This is a default catch all
          # Since the error could theoretically respond_to the
          # original_body method but still not have it
          errors_to_add << error
        end
      elsif error&.errors.present?
        errors_to_add.concat(error.errors)
      end

      # Add all collected errors to the auto_claim evss_response
      auto_claim.evss_response.concat(errors_to_add)

      auto_claim.save!
    end

    def get_error_message(error)
      if error_responds_to_original_body?(error)
        error.original_body
      elsif error.respond_to? :message
        error.message
      elsif error.respond_to? :errors
        error.errors
      elsif error.respond_to? :detailed_message
        error.detailed_message
      else
        error
      end
    end

    def get_error_key(error_message)
      return error_message if error_message.is_a? String

      error_message&.dig(:messages, 0, :key) || error_message&.dig(:key)
    end

    def get_error_text(error_message)
      return error_message if error_message.is_a? String

      error_message&.dig(:messages, 0, :text) || error_message&.dig(:text) ||
        error_message&.dig(:message) || error_message&.dig(:detail)
    end

    def get_error_status_code(error)
      if error.respond_to? :status_code
        error.status_code
      else
        "No status code for error: #{error}"
      end
    end

    def get_original_status_code(error)
      if error.respond_to? :original_status
        error.original_status
      else
        ''
      end
    end

    def will_retry?(auto_claim, error)
      msg = if auto_claim.evss_response.present?
              auto_claim.evss_response&.dig(0, 'key')
            elsif error_responds_to_original_body?(error)
              get_error_key(error.original_body)
            else
              ''
            end
      # If there is a match return false because we will not retry
      NO_RETRY_ERROR_CODES.exclude?(msg)
    end

    def will_retry_status_code?(error)
      status = get_original_status_code(error)
      RETRY_STATUS_CODES.include?(status.to_s)
    end

    def get_claim(claim_id)
      ClaimsApi::AutoEstablishedClaim.find(claim_id)
    end

    def established_state_value
      ClaimsApi::AutoEstablishedClaim::ESTABLISHED
    end

    def pending_state_value
      ClaimsApi::AutoEstablishedClaim::PENDING
    end

    def errored_state_value
      ClaimsApi::AutoEstablishedClaim::ERRORED
    end

    def log_job_progress(claim_id, detail, transaction_id = nil)
      log_data = { claim_id:, detail:, transaction_id: }
      log_data.compact!
      ClaimsApi::Logger.log(self.class::LOG_TAG, **log_data)
    end

    def error_responds_to_original_body?(error)
      error.respond_to? :original_body
    end

    def extract_poa_code(poa_form_data)
      if poa_form_data.key?('serviceOrganization')
        poa_form_data['serviceOrganization']['poaCode']
      elsif poa_form_data.key?('representative') # V2 2122a
        poa_form_data['representative']['poaCode']
      end
    end

    def evss_mapper_service(auto_claim)
      ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim)
    end

    def veteran_file_number(auto_claim)
      auto_claim.auth_headers['va_eauth_birlsfilenumber']
    end

    def evss_service
      ClaimsApi::EVSSService::Base.new
    end

    def rescue_generic_errors(power_of_attorney, e)
      power_of_attorney.status = ClaimsApi::PowerOfAttorney::ERRORED
      power_of_attorney.vbms_error_message = e&.message || e&.original_body
      power_of_attorney.save
      ClaimsApi::Logger.log('ServiceBase', message: "In generic rescue, the error is: #{e}")
    end
  end
end
