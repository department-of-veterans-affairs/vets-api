# frozen_string_literal: true

class FormProfiles::VA10203 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
