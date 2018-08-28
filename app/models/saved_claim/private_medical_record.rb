# frozen_string_literal: true

class SavedClaim::PrivateMedicalRecord < SavedClaim
  include SetGuid
  FORM = '21-4142'
  # add_form_and_validation('21-4142')

end
