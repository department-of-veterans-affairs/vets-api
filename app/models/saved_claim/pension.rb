# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::Pension < CentralMailClaim
  FORM = '21P-527EZ'

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.veteranAddress.postalCode)
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
end
