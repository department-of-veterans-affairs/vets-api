# frozen_string_literal: true

class FormProfiles::MDOT < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
