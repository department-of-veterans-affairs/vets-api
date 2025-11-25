# frozen_string_literal: true

class FormProfiles::VA0803 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
