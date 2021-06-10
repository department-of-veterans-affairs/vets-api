# frozen_string_literal: true

class FormProfiles::VA10182 < FormProfiles::DecisionReview
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-details'
    }
  end
end
