# frozen_string_literal: true

module BenefitsIntake
  module SubmissionHandler
    class SavedClaim
      class << self

        def handle(result, saved_claim_id, call_location: nil)
          @claim = claim_class.find(saved_claim_id)
        end

        private

        def claim_class
          ::SavedClaim
        end

      end
    end
  end
end
