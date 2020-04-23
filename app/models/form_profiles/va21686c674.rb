# frozen_string_literal: true

class FormProfiles::VA21686c674 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      # TODO get correct returnUrl
      returnUrl: '/claimant-information'
    }
  end
end
