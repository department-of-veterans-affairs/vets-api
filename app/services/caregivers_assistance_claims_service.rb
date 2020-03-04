# frozen_string_literal: true

class CaregiversAssistanceClaimsService
  def submit_claim!(user_context, claim_data)
    claim = SavedClaim::CaregiversAssistanceClaim.new(claim_data)

    unless claim.valid?
      # If we've reached here, there is an client error that prevented the claim, increment relevant stat.
      # TODO (kevinmirc): #5672
      raise(Common::Exceptions::ValidationErrors, claim)
    end

    begin
      claim.save!
    rescue => e
      # If we've reached here, there is an internal error that prevented claim, log error and increment stat.
      # TODO (kevinmirc): #5672
      raise e
    end

    # If we've made it here, increment success stat
    # TODO (kevinmirc): #5672

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
