# frozen_string_literal: true

# This service manages the interactions between CaregiversAssistancesClaims, CARMA, and Form1010cg::Submissions.
module Form1010cg
  class Service
    def submit_claim!(user_context, claim_data)
      claim = SavedClaim::CaregiversAssistanceClaim.new(claim_data)
      claim.valid? || raise(Common::Exceptions::ValidationErrors, claim)

      carma_submission = CARMA::Models::Submission.from_claim(claim)
      carma_submission.submit!

      submission = Form1010cg::Submission.new(
        carma_case_id: carma_submission.case_id,
        submitted_at: carma_submission.submitted_at
      )

      destroy_previously_saved_form_for(user_context) if user_context

      submission
    end

    private

    # Destroy this form it has previously been stored in-progress by this user_context
    def form_schema_id
      SavedClaim::CaregiversAssistanceClaim::FORM
    end

    def destroy_previously_saved_form_for(user_context)
      InProgressForm.form_for_user(form_schema_id, user_context)&.destroy
    end
  end
end
