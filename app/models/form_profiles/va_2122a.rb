# frozen_string_literal: true

class FormProfiles::VA2122A < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/claimant-personal-information'
    }
  end
end
