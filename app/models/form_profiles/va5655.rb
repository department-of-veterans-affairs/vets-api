# frozen_string_literal: true

class FormProfiles::VA5655 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/5655/applicant/information'
    }
  end
end
