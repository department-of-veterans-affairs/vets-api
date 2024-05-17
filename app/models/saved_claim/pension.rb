# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::Pension < CentralMailClaim
  FORM = '21P-527EZ'

  def regional_office
    ['Department of Veteran Affairs',
     'Pension Intake Center',
     'P.O. Box 5365',
     'Janesville, Wisconsin 53547-5365']
  end

  def business_line
    'PMC'
  end

  def attachment_keys
    [:files].freeze
  end

  def email
    parsed_form['email']
  end

  def send_confirmation_email
    return if email.blank?

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form527ez_confirmation_email,
      {
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => guid
      }
    )
  end

  # Send this Pension claim to the Lighthouse Benefit Intake API
  # https://developer.va.gov/explore/api/benefits-intake/docs
  # @see Lighthouse::PensionBenefitIntakeJob
  def upload_to_lighthouse(current_user = nil)
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    Lighthouse::PensionBenefitIntakeJob.perform_async(id, current_user&.uuid)
  end
end
