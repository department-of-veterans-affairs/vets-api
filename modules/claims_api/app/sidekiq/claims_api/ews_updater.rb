# frozen_string_literal: true

require 'bgs'
require 'bgs_service/benefit_claim_web_service'

module ClaimsApi
  class EwsUpdater < ClaimsApi::ServiceBase
    FILE_5103 = 'Y'
    OMITTED_FIELDS = %w[contentions dvlpmt_items letters name status_messages station_profile stn_suspns_prfil].freeze
    sidekiq_options expires_in: 48.hours, retry: true

    def perform(ews_id)
      ews = ClaimsApi::EvidenceWaiverSubmission.find(ews_id)
      bgs_claim = benefit_claim_web_service(ews).find_bnft_claim(claim_id: ews.claim_id)

      if bgs_claim&.dig(:bnft_claim_dto).blank?
        ews.status = ClaimsApi::EvidenceWaiverSubmission::ERRORED
        ClaimsApi::Logger.log('ews_updater',
                              detail: "bnft_claim_dto, filed5103_waiver_ind is not present on claim: #{ews.claim_id},
          and ews_id: #{ews.id}, and bgs_claim keys: #{bgs_claim&.keys}.")
      else
        bgs_claim[:bnft_claim_dto][:filed5103_waiver_ind] = FILE_5103
        update_bgs_claim(ews, bgs_claim)
      end
      ews.save
      ews
    end

    private

    def benefit_claim_web_service(ews)
      @bms ||= ClaimsApi::BenefitClaimWebService.new(external_uid: ews.auth_headers['va_eauth_pnid'],
                                                     external_key: ews.auth_headers['va_eauth_pnid'])
    end

    def update_bgs_claim(ews, bgs_claim)
      response = get_response(ews, bgs_claim)
      if response[:bnft_claim_dto].nil?
        ews.status = ClaimsApi::EvidenceWaiverSubmission::ERRORED
        ews.bgs_error_message = "BGS Error: update_record failed with code #{response[:return_code]}"
        ews.bgs_upload_failure_count = ews.bgs_upload_failure_count + 1
        ClaimsApi::Logger.log('ews_updater', ews_id: ews.id, claim_id: ews.claim_id,
                                             detail: 'Waiver update Failed', error: response[:return_code],
                                             failure_count: ews.bgs_upload_failure_count)
      else
        ClaimsApi::Logger.log('ews_updater', ews_id: ews.id, claim_id: ews.claim_id,
                                             detail: 'Waiver update Success')
        ews.status = ClaimsApi::EvidenceWaiverSubmission::UPDATED
      end
    end

    def get_response(ews, bgs_claim)
      if Flipper.enabled? :claims_api_ews_updater_enables_local_bgs
        benefit_claim_web_service(ews).update_bnft_claim(claim: bgs_claim)
      else
        bgs_service(ews).benefit_claims.update_bnft_claim(claim: bgs_claim)
      end
    end

    def bgs_service(ews)
      BGS::Services.new(external_uid: ews.auth_headers['va_eauth_pnid'],
                        external_key: ews.auth_headers['va_eauth_pnid'])
    end
  end
end
