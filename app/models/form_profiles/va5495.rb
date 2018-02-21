# frozen_string_literal: true

class FormProfiles::VA5495 < FormProfile
  def prefill(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/5495/applicant/information'
    }
  end
end
