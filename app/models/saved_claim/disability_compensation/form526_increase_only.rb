# frozen_string_literal: true

require 'evss/disability_compensation_form/data_translation'

class SavedClaim::DisabilityCompensation::Form526IncreaseOnly < SavedClaim::DisabilityCompensation
  add_form_and_validation('21-526EZ')

  TRANSLATION_CLASS = EVSS::DisabilityCompensationForm::DataTranslation
end
