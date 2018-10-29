# frozen_string_literal: true

class SavedClaim::DisabilityCompensation::Form526IncreaseOnly < SavedClaim::DisabilityCompensation
  add_form_and_validation('21-526EZ')

  private

  def translate_data(user, form526)
    EVSS::DisabilityCompensationForm::DataTranslation.new(user, form526).translate
  end
end
