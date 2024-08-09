# frozen_string_literal: true

class FormProfiles::FormMockAeDesignPatterns < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-details'
    }
  end
end
