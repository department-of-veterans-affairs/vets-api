# frozen_string_literal: true

class FormProfiles::VA0993 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/claimant-information'
    }
  end
end
