# frozen_string_literal: true

class FormProfiles::VA281900 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information-review'
    }
  end
end
