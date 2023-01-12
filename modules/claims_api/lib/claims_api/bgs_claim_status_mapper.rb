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
      'errored' => 'ERRORED',
      'complete' => 'COMPLETE'
    }.freeze

    BGS_PHASE_TO_STATUS = {
      1 => 'Claim received',
      2 => 'Initial review',
      3 => 'Gathering of Evidence',
      4 => 'Review of Evidence',
      5 => 'Preparation for Decision',
      6 => 'Pending Decision Approval',
      7 => 'Preparation for notification',
      8 => 'Complete'
    }.freeze

    def initialize(claim_data, phase_number = 0)
      return if claim_data.nil?

      @phase_number = phase_number
      @claim_details = claim_data
      @phase_type = @phase_number unless @phase_number.nil?
      @phase = get_status_from_claim(claim_data).downcase
    end

    def name
      return 'no status received' if @phase.nil? || @phase.strip.empty?

      PHASE_TO_STATUS[@phase]
    end

    def name_from_phase
      return 'no status received' if @phase_type.nil? || @phase_type.strip.empty?

      BGS_PHASE_TO_STATUS[@phase_number]
    end

    def get_status_from_claim(claim_data)
      if !claim_data[:status].nil? && claim_data[:status].is_a?(Hash)
        claim_data.dig(:status, :phase_type)
      elsif !claim_data.dig(:claim_phase_dates, :latest_phase_type).nil?
        claim_data.dig(:claim_phase_dates, :latest_phase_type)
      elsif !claim_data[:status].nil?
        claim_data[:status]
      elsif !claim_data[:phase_type].nil?
        claim_data[:phase_type]
      else
        'Claim received'
      end
    end
  end
end
