# frozen_string_literal: true

class FormProfile::VA1990n < FormProfile
  def prefill(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/1990n/applicant/information'
    }
  end
end
