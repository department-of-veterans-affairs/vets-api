# frozen_string_literal: true

class FormProfiles::VIC < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
