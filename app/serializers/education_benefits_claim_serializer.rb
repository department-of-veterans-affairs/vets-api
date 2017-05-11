# frozen_string_literal: true
class EducationBenefitsClaimSerializer < ActiveModel::Serializer
  attributes :id, :form, :submitted_at, :regional_office, :confirmation_number
  attribute :spool, if: proc { Rails.env.development? }

  def spool
    EducationForm::Forms::Base.build(object).text
  rescue
    ''
  end
end
