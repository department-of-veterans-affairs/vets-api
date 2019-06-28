# frozen_string_literal: true

module ClaimsApi
  class EVSSClaim
    include Virtus.model
    include ActiveModel::Serialization

    #############################
    # This mapping exists on the front end here:
    # - https://github.com/department-of-veterans-affairs/vets-website/blob/fcf944bd4319684f5eb3d1901606801d01a9a55e/src/applications/claims-status/utils/helpers.js#L9
    # As of the time of this comment they exist as the source of truth for this information
    # in the future we'll likely try to make this the source of truth
    #############################
    EVIDENCE_GATHERING = 'Evidence gathering, review, and decision'

    PHASE_TO_STATUS = {
      1 => 'Claim recieved',
      2 => 'Initial review',
      3 => EVIDENCE_GATHERING,
      4 => EVIDENCE_GATHERING,
      5 => EVIDENCE_GATHERING,
      6 => EVIDENCE_GATHERING,
      7 => 'Preparation for notification',
      8 => 'Complete'
    }.freeze

    attribute :evss_id, Integer
    attribute :data, Hash
    attribute :list_data, Hash

    def requested_decision
      false
    end

    def updated_at
      nil
    end

    def status_from_phase(phase)
      PHASE_TO_STATUS[phase]
    end

    def supporting_documents
      auto_established_claim = ClaimsApi::AutoEstablishedClaim.find_by evss_id: evss_id
      if auto_established_claim.present?
        auto_established_claim.supporting_documents.map do |document|
          {
            id: document.id,
            type: 'claim_supporting_document',
            md5: document.file_data['filename'].present? ? Digest::MD5.hexdigest(document.file_data['filename']) : '',
            filename: document.file_data['filename'],
            uploaded_at: document.created_at
          }
        end
      else
        []
      end
    end

    def self.services_are_healthy?
      last_mvi_outage = Breakers::Outage.find_latest(service: MVI::Configuration.instance.breakers_service)
      mvi_up = (last_mvi_outage.blank? || last_mvi_outage.end_time.present?)

      last_evss_claims_outage = Breakers::Outage.find_latest(service: EVSS::ClaimsService.breakers_service)
      evss_claims_up = last_evss_claims_outage.blank? || last_evss_claims_outage.end_time.present?

      last_evss_common_outage = Breakers::Outage.find_latest(service: EVSS::CommonService.breakers_service)
      evss_common_up = last_evss_common_outage.blank? || last_evss_common_outage.end_time.present?
      mvi_up && evss_claims_up && evss_common_up
    end

    def self.healthy_service_response
        {
          data:  {
            id: 'claims_healthcheck',
            type: 'claims_healthcheck',
            attributes: {
              healthy: true,
              date: Time.zone.now.to_formatted_s(:iso8601)
            }
          }
        }.to_json
    end

    def self.unhealthy_service_response
      {
        errors: [
          {
            title: 'ClaimsAPI Unavailable',
            detail: 'ClaimsAPI is currently unavailable.',
            code: '503',
            status: '503'
          }
        ]
      }.to_json
    end
  end
end
