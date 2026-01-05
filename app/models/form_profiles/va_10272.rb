# frozen_string_literal: true

class FormProfiles::VA10272 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end

  def va_file_number
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    response.file_number.presence
  end
end
