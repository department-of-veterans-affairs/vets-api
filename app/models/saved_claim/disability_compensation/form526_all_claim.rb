# frozen_string_literal: true

class SavedClaim::DisabilityCompensation::Form526AllClaim < SavedClaim::DisabilityCompensation
  # TODO: AEC
  add_form_and_validation('21-526EZ-ALLCLAIMS')

  TRANSLATION_CLASS = EVSS::DisabilityCompensationForm::DataTranslationAllClaim
end
