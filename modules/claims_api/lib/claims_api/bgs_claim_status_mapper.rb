# frozen_string_literal: true

module ClaimsApi
  class BGSClaimStatusMapper
    PHASE_STATUS_DICTIONARY = {
      CANCELED: %w[0 cancelled can canceled],
      CLAIM_RECEIVED: ['1', 'claim received', 'received', 'open'],
      INITIAL_REVIEW: ['2', 'initial review', 'review', 'under review'],
      PENDING: %w[pending pend],
      EVIDENCE_GATHERING: ['3', 'evidence gathering', 'gathering of evidence'],
      REVIEW_OF_EVIDENCE: ['4', 'review of evidence', 'Review of Evidence'],
      PREPARATION_FOR_DECISION: ['5', 'preparation for decision', 'rfd'],
      PENDING_DECISION_APPROVAL: ['6', 'pending decision approval'],
      PREPARATION_FOR_NOTIFICATION: ['7', 'preparation for notification', 'prep'],
      ERRORED: %w[errored error],
      COMPLETE: %w[8 complete comp clr cld]
    }.freeze

    def name(claim_data, phase_number = nil)
      phase = get_status_from_claim(claim_data, phase_number)
      get_status_from_dictionary(phase)
    end

    def get_status_from_claim(claim_data, phase_number)
      return 'no status received' if claim_data.nil? && phase_number.nil?

      status = case claim_data
               when String
                 claim_data
               when ClaimsApi::AutoEstablishedClaim
                 claim_data.status
               when Hash
                 claim_data[:phase_number].presence ||
                 claim_data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).presence ||
                 claim_data[:claim_status].presence ||
                 claim_data[:status].presence ||
                 claim_data[:phase_type].presence ||
                 claim_data&.dig(:claim_phase_dates, :latest_phase_type).presence
               when OpenStruct
                 claim_data.status.presence
               end
      status.is_a?(String) ? status.downcase : status.to_s
    end

    def get_status_from_dictionary(phase)
      status = ''
      PHASE_STATUS_DICTIONARY.each do |key, value|
        status = key.to_s if value.include?(phase.to_s)
      end
      grouped_phase(status)
    end

    def get_phase_from_phase_type_ind(phase_type_ind)
      phase = ''
      PHASE_STATUS_DICTIONARY.each do |_key, value|
        phase = value[1].to_s if value.include?(phase_type_ind.to_s)
      end
      phase
    end

    def grouped_phase(status_from_dictionary)
      if %w[EVIDENCE_GATHERING REVIEW_OF_EVIDENCE PREPARATION_FOR_DECISION
            PENDING_DECISION_APPROVAL].include?(status_from_dictionary)
        'EVIDENCE_GATHERING_REVIEW_DECISION'
      else
        status_from_dictionary
      end
    end
  end
end
