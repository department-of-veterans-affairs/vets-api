# frozen_string_literal: true

class FormProfiles::ComplaintTool < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-relationship'
    }
  end
end
