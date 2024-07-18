# frozen_string_literal: true

module Mobile
  module V0
    class EnrollmentStatusSerializer
      include JSONAPI::Serializer

      set_type :enrollment_status

      attributes :application_date, :enrollment_date, :preferred_facility, :parsed_status, :primary_eligibility,
                 :can_submit_financial_info
    end
  end
end
