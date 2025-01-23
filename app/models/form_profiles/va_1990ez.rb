# frozen_string_literal: true

class FormProfiles::VA1990ez < FormProfile
  def return_url
    if Flipper.enabled?(:meb_1606_30_automation)
      '/benefit-selection'
    else
      '/applicant-information/personal-information'
    end
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: return_url
    }
  end
end
