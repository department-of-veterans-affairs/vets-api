# frozen_string_literal: true

class CaregiversAssistanceClaimsService
  def submit_application!(user, application_data)
    claim = SavedClaim::CaregiversAssistanceClaim.new(application_data)

    unless claim.valid?
      # TODO: If we've reached here, there is an client error that prevented the claim, log increment relevant stats.
      # StatsD.increment("#{stats_key}.failure")
      raise(Common::Exceptions::ValidationErrors, claim)
    end

    begin
      claim.save!
    rescue => e
      # TODO: If we've reached here, there is an internal error that prevented claim, log error and increment stats.
      # StatsD.increment("#{stats_key}.failure")
      raise e
    end

    # TODO: If we've made it here, log success and
    # StatsD.increment("#{stats_key}.success")
    # Rails.logger.info "ClaimID=#{claim.id} Form=#{form_id}" # TODO: Is there a convention for claims?

    destroy_previously_saved_form_for(user) if user

    claim
  end

  private

  # Destroy this form it has previously been stored in-progress by this user
  def form_schema_id
    SavedClaim::CaregiversAssistanceApplication::FORM
  end

  def destroy_previously_saved_form_for(user)
    InProgressForm.form_for_user(form_schema_id, user)&.destroy
  end

  # def stats_key
  #   # TODO: What's the naming convention here?
  #   # docs: https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/backend/sending-metrics-using-statsd.md
  #   "api.caregivers_assistance_claims"
  # end
end
