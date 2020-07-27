# frozen_string_literal: true

# This service manages the interactions between CaregiversAssistanceClaim, CARMA, and Form1010cg::Submission.
module Form1010cg
  class Service
    def submit_claim!(claim_data)
      claim = SavedClaim::CaregiversAssistanceClaim.new(claim_data)
      claim.valid? || raise(Common::Exceptions::ValidationErrors, claim)

      carma_submission = CARMA::Models::Submission.from_claim(claim)

      carma_submission.submit!

      Form1010cg::Submission.new(
        carma_case_id: carma_submission.carma_case_id,
        submitted_at: carma_submission.submitted_at
      )
    end

    private

    # Destroy this form it has previously been stored in-progress by this user_context
    def form_schema_id
      SavedClaim::CaregiversAssistanceClaim::FORM
    end
  end
end
