# frozen_string_literal: true

class FormProfiles::VHA1010d < FormProfile
  FORM_ID = '10-10D'

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/signer-type'
    }
  end
end
