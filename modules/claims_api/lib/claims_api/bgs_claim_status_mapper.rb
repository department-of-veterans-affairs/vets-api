# frozen_string_literal: true

# Maps a given 'status' to a known enum status

module ClaimsApi
  class BGSClaimStatusMapper
    EVIDENCE_GATHERING = 'EVIDENCE_GATHERING_REVIEW_DECISION'

    PHASE_TO_STATUS = {
      'claim received' => 'CLAIM_RECEIVED',
      'initial review' => 'INITIAL_REVIEW',
      'pending' => 'PENDING',
      'evidence gathering' => EVIDENCE_GATHERING,
      'review of evidence' => EVIDENCE_GATHERING,
      'preparation for decision' => EVIDENCE_GATHERING,
      'pending decision approval' => EVIDENCE_GATHERING,
      'preparation for notification' => 'PREPARATION_FOR_NOTIFICATION',
      'complete' => 'COMPLETE'
    }.freeze

    def initialize(phase)
      @phase = phase.downcase unless phase.nil?
    end

    def name
      return 'no status received' if @phase.nil? || @phase.strip.empty?

      PHASE_TO_STATUS[@phase]
    end
  end
end
