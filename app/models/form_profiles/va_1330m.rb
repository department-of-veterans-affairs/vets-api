# frozen_string_literal: true

class FormProfiles::VA1330m < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-name'
    }
  end
end
