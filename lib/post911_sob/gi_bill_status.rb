# frozen_string_literal: true

require 'common/models/base'
require 'lighthouse/benefits_education/entitlement'
require 'lighthouse/benefits_education/enrollment'

module Post911SOB
  class GIBillStatus < Common::Base
    attribute :first_name, String
    attribute :last_name, String
    attribute :name_suffix, String
    attribute :date_of_birth, String
    attribute :va_file_number, String
    attribute :regional_processing_office, String
    attribute :eligibility_date, String
    attribute :delimiting_date, String
    attribute :percentage_benefit, Integer
    attribute :original_entitlement, BenefitsEducation::Entitlement
    attribute :used_entitlement, BenefitsEducation::Entitlement
    attribute :entitlement_transferred_out, BenefitsEducation::Entitlement
    attribute :remaining_entitlement, BenefitsEducation::Entitlement
    attribute :veteran_is_eligible, Boolean
    attribute :active_duty, Boolean
    attribute :enrollments, Array[BenefitsEducation::Enrollment]

    def initialize(lighthouse_response: nil, dgib_response: nil)
      attributes = lighthouse_response.try(:attributes) || {}
      entitlement_transferred_out = {
        months: dgib_response&.entitlement_transferred_out&.months,
        days: dgib_response&.entitlement_transferred_out&.days
      }
      attributes.merge!(entitlement_transferred_out:)
      super(attributes)
      # Do we need to serialize status if it is combination of two responses?
    end
  end
end
