# frozen_string_literal: true

class FormProfiles::VA1919 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
