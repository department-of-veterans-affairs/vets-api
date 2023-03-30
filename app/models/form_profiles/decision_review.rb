# frozen_string_literal: true

class FormProfiles::DecisionReview < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  private

  def street3
    vet360_mailing_address&.address_line3
  end

  def va_file_number_last_four
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    (
      response.file_number.presence || user.ssn.presence
    )&.last(4)
  end
end
