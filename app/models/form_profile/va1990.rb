# frozen_string_literal: true
class FormProfile::VA1990 < FormProfile
  def prefill(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/1990/applicant/information'
    }
  end
end
