# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'claims_api/v2/disability_compensation_fes_mapper'
require 'claims_api/v1/disability_compensation_fes_mapper'
require 'evss_service/base'
require 'fes_service/base'

module ClaimsApi
  module DisabilityCompensation
    class Form526EstablishmentService < ServiceBase
      LOG_TAG = '526_v2_form526_establishment_service'
      ASYNC = false

      def upload(claim_id)
        auto_claim = get_claim(claim_id)
        log_job_progress(claim_id, 'Form526 Establishment service started', auto_claim.transaction_id)
        update_auth_headers(auto_claim) if auto_claim.transaction_id.present?

        case claim_version(auto_claim)
        when :v1
          if Flipper.enabled?(:lighthouse_claims_api_v1_enable_FES)
            submit_fes(claim_id, auto_claim, get_v1_fes_data(auto_claim), 'v1')
          else
            submit_evss(claim_id, auto_claim, get_evss_data(auto_claim), 'v1')
          end
        when :v2
          if Flipper.enabled?(:lighthouse_claims_api_v2_enable_FES)
            submit_fes(claim_id, auto_claim, get_fes_data(auto_claim), 'v2')
          else
            submit_evss(claim_id, auto_claim, get_evss_data(auto_claim), 'v2')
          end
        else
          raise ArgumentError, "Unknown claim version for claim_id=#{claim_id}"
        end
      rescue => e
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.evss_response = e.errors if e.methods.include?(:errors)
        auto_claim.save
        raise e
      end

      # rubocop:enable Metrics/MethodLength

      private

      def update_auth_headers(auto_claim)
        updated_auth_headers = auto_claim.auth_headers
        updated_auth_headers['va_eauth_service_transaction_id'] = auto_claim.transaction_id
        auto_claim.update!(auth_headers: updated_auth_headers)
      end

      def claim_version(auto_claim)
        version_control = auto_claim.respond_to?(:api_version) ? auto_claim.api_version&.to_sym : nil
        return version_control if version_control

        data = auto_claim.form_data || {}
        return :v2 if data.key?('veteranIdentification') || data.key?(:veteranIdentification)
        return :v1 if data.key?('veteran') || data.key?(:veteran)

        :v1
      end

      def submit_fes(claim_id, auto_claim, payload, tag)
        log_job_progress(claim_id, "Submitting mapped data to FES (#{tag})", auto_claim.transaction_id)
        fes_res = fes_service.submit(auto_claim, payload, ASYNC)
        log_job_progress(claim_id, "Submitted to FES (#{tag}) with response: #{fes_res}", auto_claim.transaction_id)
        auto_claim.update!(evss_id: fes_res[:claimId] || fes_res['claimId'])
      end

      def submit_evss(claim_id, auto_claim, payload, tag)
        log_job_progress(claim_id, "Submitting mapped data to 526 Establishment service (#{tag})",
                         auto_claim.transaction_id)
        evss_res = evss_service.submit(auto_claim, payload, ASYNC)
        log_job_progress(claim_id, "Submitted to 526 Establishment service (#{tag}) with response: #{evss_res}",
                         auto_claim.transaction_id)
        auto_claim.update!(evss_id: evss_res[:claimId] || evss_res['claimId'])
      end

      def get_evss_data(auto_claim)
        evss_mapper_service(auto_claim).map_claim
      end

      def get_fes_data(auto_claim)
        fes_mapper_service(auto_claim).map_claim
      end

      def get_v1_fes_data(auto_claim)
        v1_fes_mapper_service(auto_claim).map_claim
      end
    end
  end
end
