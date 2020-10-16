# frozen_string_literal: true

class FormProfiles::VA0873 < FormProfile
  class FormAddress
    include Virtus.model

    attribute :fullName, String
  end

  def prefill
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/topic'
    }
  end
end
