# frozen_string_literal: true

module ClaimsApi
  class EVSSClaim
    include Virtus.model
    include ActiveModel::Serialization

    EVIDENCE_GATHERING = 'Gathering of evidence'

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
  end
end
