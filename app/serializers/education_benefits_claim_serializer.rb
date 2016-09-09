# frozen_string_literal: true
class EducationBenefitsClaimSerializer < ActiveModel::Serializer
  attributes :id, :form, :submitted_at, :processed_at
end
