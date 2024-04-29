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
    end

    protected

    def set_established_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
    end

    def clear_evss_response_for_claim(auto_claim)
      auto_claim.evss_response = nil
      save_auto_claim!(auto_claim, auto_claim.status)
    end

    def set_errored_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::ERRORED)
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
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      auto_claim.save!

      auto_claim.evss_response = []
      error_messages = get_error_message(error)
      messages = error_messages&.dig(0, :messages).presence ? error_messages[:messages] : [error_messages]

      messages.flatten.uniq.each do |error_message|
        error_key = get_error_key(error_message)
        error_text = get_error_text(error_message)
        auto_claim.evss_response <<
          { 'key' => error_key,
            'severity' => 'FATAL',
            'text' => error_text }
      end

      save_auto_claim!(auto_claim, auto_claim.status)
    end

    def get_error_message(error)
      if error.respond_to? :original_body
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

      error_message&.dig(:messages, 0, :text) || error_message&.dig(:text)
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
            elsif error.respond_to? :original_body
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

    def log_job_progress(claim_id, detail)
      ClaimsApi::Logger.log(self.class::LOG_TAG,
                            claim_id:,
                            detail:)
    end

    def extract_poa_code(poa_form_data)
      if poa_form_data.key?('serviceOrganization')
        poa_form_data['serviceOrganization']['poaCode']
      elsif poa_form_data.key?('representative') # V2 2122a
        poa_form_data['representative']['poaCode']
      end
    end
  end
end
