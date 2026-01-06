# frozen_string_literal: true

class FormProfiles::VA21p601 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/personal-information'
    }
  end
end
