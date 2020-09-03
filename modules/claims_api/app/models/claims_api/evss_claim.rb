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
      1 => 'Claim received',
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
  end
end
