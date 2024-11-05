# frozen_string_literal: true

class FormProfiles::VHA107959c < FormProfile
  FORM_ID = '10-7959C'

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-info'
    }
  end
end
