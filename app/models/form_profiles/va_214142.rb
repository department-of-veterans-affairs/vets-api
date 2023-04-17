# frozen_string_literal: true

class FormProfiles::VA214142 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/personal-information-1'
    }
  end
end
