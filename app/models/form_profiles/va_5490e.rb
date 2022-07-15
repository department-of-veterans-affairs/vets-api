# frozen_string_literal: true

class FormProfiles::VA5490e < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
