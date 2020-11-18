# frozen_string_literal: true

require 'sentry_logging'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging
  FORM = '28-1900'

  def add_claimant_info(user)
    return if form.blank?

    updated_form = parsed_form

    updated_form['veteranInformation'] = {
      'fullName' => {
        'first' => user.first_name,
        'middle' => user.middle_name || '',
        'last' => user.last_name
      },
      'ssn' => user.ssn,
      'VAFileNumber' => veteran_va_file_number(user),
      'pid' => user.participant_id,
      'edipi' => user.edipi,
      'vet360ID' => user.vet360_id,
      'dob' => user.birth_date
    }

    update(form: updated_form.to_json)
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  private

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    response = service.find_person_by_participant_id

    response[:file_nbr]
  rescue
    nil
  end
end
