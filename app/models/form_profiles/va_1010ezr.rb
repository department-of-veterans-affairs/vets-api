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
    @ezr_data ||=
      begin
        if Flipper.enabled?(:ezr_form_prefill_with_providers_and_dependents)
          HCA::EnrollmentEligibility::Service.new.get_ezr_data(user.icn)
        else
          ezr_data = HCA::EnrollmentEligibility::Service.new.get_ezr_data(
            user.icn
          )
          ezr_data.delete_field('providers')
          ezr_data.delete_field('dependents')

          ezr_data
        end
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
