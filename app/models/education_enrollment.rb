# frozen_string_literal: true
require 'common/models/base'

class EducationEnrollment < Common::Base
  # EVSS provides these but we already have from User model
  # TODO - validate they match?
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

  attribute :facilities, Array[Object]
end
