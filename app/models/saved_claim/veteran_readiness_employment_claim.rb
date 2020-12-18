# frozen_string_literal: true

require 'sentry_logging'
require 'vre/ch31_form'

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
      'dob' => parsed_date(user.birth_date)
    }

    update(form: updated_form.to_json)
  end

  def send_to_vre(user)
    prepare_form_data
    service = VRE::Ch31Form.new(user: user, claim: self)

    service.submit
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  private

  def prepare_form_data
    form_copy = parsed_form
    appointment_time_preferences = form_copy['appointmentTimePreferences'].map do |key_value|
      key_value[0] if key_value[1] == true
    end.compact

    # VRE now needs an array of times
    form_copy['appointmentTimePreferences'] = appointment_time_preferences

    update(form: form_copy.to_json)
  end

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    response = service.find_person_by_participant_id
    file_number = response[:file_nbr]
    file_number.presence
  rescue
    nil
  end

  def parsed_date(date)
    date.strftime('%Y-%m-%d')
  rescue
    date
  end
end
