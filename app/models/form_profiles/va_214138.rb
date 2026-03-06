# frozen_string_literal: true

class FormProfiles::VA214138 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/statement-type'
    }
  end
end
