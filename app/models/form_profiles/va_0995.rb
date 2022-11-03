# frozen_string_literal: true

class FormProfiles::VA0995 < FormProfiles::DecisionReview
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
