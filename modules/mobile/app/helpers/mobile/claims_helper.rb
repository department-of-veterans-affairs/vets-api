# frozen_string_literal: true

module Mobile
  module ClaimsHelper
    module_function

    PHASE_TYPE_TO_NUMBER = {
      CLAIM_RECEIVED: 1,
      UNDER_REVIEW: 2,
      GATHERING_OF_EVIDENCE: 3,
      REVIEW_OF_EVIDENCE: 4,
      PREPARATION_FOR_DECISION: 5,
      PENDING_DECISION_APPROVAL: 6,
      PREPARATION_FOR_NOTIFICATION: 7,
      COMPLETE: 8
    }.freeze

    def phase_to_number(phase)
      PHASE_TYPE_TO_NUMBER[phase.to_sym]
    end
  end
end
