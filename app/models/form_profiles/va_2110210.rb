# frozen_string_literal: true

class FormProfiles::VA2110210 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/claim-ownership'
    }
  end
end
