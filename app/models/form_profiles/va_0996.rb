# frozen_string_literal: true

class FormProfiles::VA0996 < FormProfile
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
    (
      BGS::PeopleService.new(user).find_person_by_participant_id[:file_nbr].presence ||
      user.ssn.presence
    )&.last(4)
  end
end
