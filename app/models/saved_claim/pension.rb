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
    return unless Flipper.enabled?(:form527ez_confirmation_email)
    return if email.blank?

    (regional_office_line_1, regional_office_line_2, regional_office_line_3) = regional_office

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form527ez_confirmation_email,
      {
        'confirmation_number' => guid,
        'pmc_name' => regional_office.first.sub('Attention:', '').strip,
        'regional_office_line_1' => regional_office_line_1,
        'regional_office_line_2' => regional_office_line_2,
        'regional_office_line_3' => regional_office_line_3,
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
      }
    )
  end
end
