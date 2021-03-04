# frozen_string_literal: true

require 'sentry_logging'
require 'vre/ch31_form'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging
  FORM = '28-1900'

  validate :veteran_information, on: :prepare_form_data

  def add_claimant_info(user)
    return if form.blank?

    updated_form = parsed_form

    updated_form['veteranInformation'].merge!(
      {
        'VAFileNumber' => updated_form['veteranInformation']['vaFileNumber'] || veteran_va_file_number(user),
        'pid' => user.participant_id,
        'edipi' => user.edipi,
        'vet360ID' => user.vet360_id,
        'dob' => user.birth_date
      }
    ).except!('vaFileNumber')

    update(form: updated_form.to_json)
  end

  def send_to_vre(user)
    prepare_form_data

    upload_to_vbms
    service = VRE::Ch31Form.new(user: user, claim: self)
    service.submit
  end

  def upload_to_vbms(doc_type: '171')
    form_path = PdfFill::Filler.fill_form(self)

    uploader = ClaimsApi::VBMSUploader.new(
      filepath: form_path,
      file_number: parsed_form['veteranInformation']['ssn'],
      doc_type: doc_type
    )

    uploader.upload!
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  private

  def prepare_form_data
    form_copy = parsed_form
    appointment_time_preferences = form_copy['appointmentTimePreferences'].map do |key_value|
      key_value[0].downcase if key_value[1] == true
    end.compact

    # VRE now needs an array of times
    form_copy['appointmentTimePreferences'] = appointment_time_preferences

    update(form: form_copy.to_json)
  end

  def veteran_information
    return errors.add(:form, 'Veteran Information is missing from form') if parsed_form['veteranInformation'].blank?
  end

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    response = service.find_person_by_participant_id
    file_number = response[:file_nbr]
    file_number.presence
  rescue
    nil
  end
end
