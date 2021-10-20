# frozen_string_literal: true

class FormProfiles::VA1990ez < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-information/personal-information'
    }
  end
end
