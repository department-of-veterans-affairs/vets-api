# frozen_string_literal: true

class FormProfiles::VA526ez < FormProfile
  def prefill(user)
    @rated_disabilities_information = initialize_rated_disabilities_information(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
