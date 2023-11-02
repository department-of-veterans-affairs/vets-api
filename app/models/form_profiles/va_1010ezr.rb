# frozen_string_literal: true

require 'hca/enrollment_eligibility/service'

class FormProfiles::VA1010ezr < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information/personal-information'
    }
  end

  def ezr_data
    @ezr_data ||= HCA::EnrollmentEligibility::Service.new.get_ezr_data(user.icn)
  end
end
