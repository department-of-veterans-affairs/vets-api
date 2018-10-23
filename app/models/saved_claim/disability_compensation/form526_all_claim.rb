# frozen_string_literal: true

class SavedClaim::DisabilityCompensation::Form526AllClaim < SavedClaim::DisabilityCompensation
  add_form_and_validation('21-526EZ-all-claim')

  private

  def translate_data(user, form526)
    # TODO: This needs to implemented once EVSS has finalized their endpoint
    EVSS::DisabilityCompensationForm::DataTranslationAllClaim.new(user, form526).translate
  end
end
