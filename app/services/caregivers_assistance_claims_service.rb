# frozen_string_literal: true

class CaregiversAssistanceClaimsService
  def submit_claim!(user_context, claim_data)
    claim = SavedClaim::CaregiversAssistanceClaim.new(claim_data)
    claim.valid? ? claim.save! : raise(Common::Exceptions::ValidationErrors, claim)

    destroy_previously_saved_form_for(user_context) if user_context

    claim
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
