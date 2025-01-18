# frozen_string_literal: true

require 'hca/enrollment_eligibility/service'

class FormProfiles::VA1010ezr < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/check-your-personal-information'
    }
  end

  def ezr_data
    @ezr_data ||=
      begin
        HCA::EnrollmentEligibility::Service.new.get_ezr_data(user.icn)
      rescue => e
        log_exception_to_sentry(e)
        OpenStruct.new
      end
  end

  def clean!(hash)
    hash.deep_transform_keys! { |k| k.camelize(:lower) }
    Common::HashHelpers.deep_compact(hash)
  end
end
