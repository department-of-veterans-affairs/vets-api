# frozen_string_literal: true

class FormProfiles::VHA107959f2 < FormProfile
  FORM_ID = '10-7959F-2'

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
