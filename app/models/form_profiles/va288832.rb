# frozen_string_literal: true

class FormProfiles::VA288832 < FormProfile
  attribute :is_logged_in, Boolean

  def prefill(user)
    @is_logged_in = true
    super(user)
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/personal-information'
    }
  end
end
