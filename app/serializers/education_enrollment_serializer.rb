# frozen_string_literal: true
class EducationEnrollmentSerializer < ActiveModel::Serializer
  attribute :va_file_number
  attribute :regional_processing_office

  attribute :eligibility_date
  attribute :delimiting_date

  attribute :percentage_benefit

  attribute :original_entitlement_days
  attribute :used_entitlement_days
  attribute :remaining_entitlement_days

  attribute :facilities

  def id
    nil
  end
end
