# frozen_string_literal: true

class FormProfiles::FormMockPrefill < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-details'
    }
  end
end
