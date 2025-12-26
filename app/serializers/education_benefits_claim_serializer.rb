# frozen_string_literal: true

class EducationBenefitsClaimSerializer
  include JSONAPI::Serializer

  set_id :token

  attributes :form, :regional_office, :confirmation_number
end
