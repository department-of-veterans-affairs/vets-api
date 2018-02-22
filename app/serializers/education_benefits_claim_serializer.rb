# frozen_string_literal: true

class EducationBenefitsClaimSerializer < ActiveModel::Serializer
  attributes :id, :form, :regional_office, :confirmation_number
end
