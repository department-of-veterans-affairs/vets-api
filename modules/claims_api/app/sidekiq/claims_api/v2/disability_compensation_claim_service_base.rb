# frozen_string_literal: true

require 'claims_api/claim_logger'
require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'sentry_logging'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimServiceBase
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      protected

      def set_established_state_on_claim(auto_claim)
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
        auto_claim.save!
      end

      def clear_evss_response_for_claim(auto_claim)
        auto_claim.evss_response = nil
        auto_claim.save!
      end

      def set_errored_state_on_claim(auto_claim)
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.save!
      end

      def set_pending_state_on_claim(auto_claim)
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::PENDING
        auto_claim.save!
      end

      def get_error_message(error)
        if error.respond_to? :original_body
          error.original_body
        elsif error.respond_to? :message
          error.message
        elsif error.is_a?(String)
          error
        end
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

      def log_job_progress(tag, claim_id, detail)
        ClaimsApi::Logger.log(tag,
                              claim_id:,
                              detail:)
      end
    end
  end
end
