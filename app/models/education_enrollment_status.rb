# frozen_string_literal: true
require 'common/models/base'

class EducationEnrollmentStatus < Common::Base
  include ActiveModel::SerializerSupport
  # attribute :first_name, String
  # attribute :last_name, String
  attribute :va_file_number, String
  attribute :regional_processing_office, String

  attribute :eligibility_date, String
  attribute :delimiting_date, String

  attribute :percentage_benefit, Integer

  attribute :original_entitlement_days, Integer
  attribute :used_entitlement_days, Integer
  attribute :remaining_entitlement_days, Integer

  # attribute :facilities, Array[Facility]


  # validates :va_file_number,             presence: true
  # validates :regional_processing_office, presence: true
  # validates :eligibility_date,           presence: true
  # validates :delimiting_date,            presence: true
  # validates :percentage_benefit,         presence: true
  # validates :original_entitlement_days,  presence: true
  # validates :used_entitlement_days,      presence: true
  # validates :remaining_entitlement_days, presence: true
end