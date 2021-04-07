# frozen_string_literal: true

class FormProfiles::VA1990s < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/form'
    }
  end
end
