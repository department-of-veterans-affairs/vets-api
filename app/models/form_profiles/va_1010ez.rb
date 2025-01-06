# frozen_string_literal: true

class FormProfiles::VA1010ez < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/check-your-personal-information'
    }
  end
end
