# frozen_string_literal: true

class FormProfiles::VA1990ez < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: Flipper.enabled?(:meb_1606_30_automation) ? '/benefit-selection' :  '/applicant-information/personal-information'
    }
  end
end
