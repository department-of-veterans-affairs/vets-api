# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    module StepTracking
      extend ActiveSupport::Concern

      def with_tracking(saved_claim_id)
        yield
        step_success(saved_claim_id)
      rescue => error
        step_error(saved_claim_id)
        raise error
      end

      def step_success(saved_claim_id)
        submission = SavedClaim::DisabilityCompensation.find(saved_claim_id).submission
        step = DisabilityCompensationSubmissionStep.where(name: row['name'], address: address)
        Facilities::DODFacility.where(name: row['name'], address: address).first_or_create(
          id: id, name: row['name'], address: address, lat: 0.0, long: 0.0
        )
      end

      def klass
        self.class.name.demodulize
      end
    end
  end
end
