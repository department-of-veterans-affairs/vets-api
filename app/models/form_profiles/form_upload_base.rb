# frozen_string_literal: true

class FormProfiles::FormUploadBase < FormProfile
  def metadata
    {
      version: 0,
      prefill: true
    }
  end
end
