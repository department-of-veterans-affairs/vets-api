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

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form527ez_confirmation_email,
      {
        'confirmation_number' => guid,
        'pmc_name' => regional_office.first.sub('Attention:', '').strip,
        'regional_office' => regional_office.join("\n").strip,
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'last_initial' => parsed_form.dig('veteranFullName', 'last')&.first&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
      }
    )
  end
end
