# frozen_string_literal: true

class FormProfiles::FormUpload < FormProfile
  def metadata
    {
      version: 0,
      prefill: true
    }
  end
end
