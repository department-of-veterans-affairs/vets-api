# frozen_string_literal: true
class EducationEnrollmentSerializer < ActiveModel::Serializer
  attribute :first_name
  attribute :last_name
  attribute :name_suffix
  attribute :date_of_birth

  attribute :va_file_number
  attribute :regional_processing_office

  attribute :eligibility_date
  attribute :delimiting_date

  attribute :percentage_benefit

  attribute :original_entitlement
  attribute :used_entitlement
  attribute :remaining_entitlement

  attribute :enrollment_list

  def id
    nil
  end
end
