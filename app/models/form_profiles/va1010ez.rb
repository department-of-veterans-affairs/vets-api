# frozen_string_literal: true

class FormProfiles::VA1010ez < FormProfile
  def prefill(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information/personal-information'
    }
  end
end
