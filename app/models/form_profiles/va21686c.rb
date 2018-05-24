# frozen_string_literal: true

class FormProfiles::VA21686c < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
