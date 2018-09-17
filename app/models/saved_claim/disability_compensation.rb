# frozen_string_literal: true

class SavedClaim::DisabilityCompensation < SavedClaim
  has_one(
    :disability_compensation_submission,
    class_name: 'DisabilityCompensationSubmission',
    inverse_of: :disability_compensation_claim,
    dependent: :destroy
  )
  has_one(
    :async_transaction,
    through: :disability_compensation_submission,
    source: :disability_compensation_job
  )

  add_form_and_validation('21-526EZ')
end
