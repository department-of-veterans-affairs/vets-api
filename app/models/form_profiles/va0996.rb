# frozen_string_literal: true

class FormProfiles::VA0996 < FormProfile
  FORM_ID = '21-0966'

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
