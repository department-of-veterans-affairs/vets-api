# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA1990s < SavedClaim::EducationBenefits
  add_form_and_validation('22-1990S')

  # Overwrite this from SavedClaim as do not want to overwrite self.class::FORM
  def form_matches_schema
    return unless form_is_string

    errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['VRRAP'], parsed_form))
  end
end
