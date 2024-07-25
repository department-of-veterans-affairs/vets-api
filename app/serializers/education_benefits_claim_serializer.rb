# frozen_string_literal: true

class EducationBenefitsClaimSerializer
  include JSONAPI::Serializer

  attributes :form, :regional_office, :confirmation_number
end
