# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
  include SentryLogging
  FORM = '28-8832'

  def regional_office
    []
  end

  def send_to_benefits_intake!
    form_copy = parsed_form

    if form_copy['veteranSocialSecurityNumber'].blank?
      claimant_info = parsed_form['claimantInformation']
      form_copy['veteranSocialSecurityNumber'] = claimant_info['ssn'] || claimant_info['veteranSocialSecurityNumber']

      update(form: form_copy.to_json)
    end

    log_message_to_sentry(guid, :warn, { attachment_id: guid }, { team: 'vfs-ebenefits' })
    process_attachments!
  end

  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    Lighthouse::SubmitBenefitsIntakeClaim.new.perform(id)
  end

  def business_line
    'EDU'
  end

  # this failure email is not the ideal way to handle the Notification Emails as
  # part of the ZSF work, but with the initial timeline it handles the email as intended.
  # Future work will be integrating into the Va Notify common lib:
  # https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/veteran_facing_services/notification_email.rb
  def send_failure_email(email)
    if email.present?
      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.form27_8832_action_needed_email,
        {
          'first_name' => parsed_form.dig('claimantInformation', 'fullName', 'first')&.upcase.presence,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => confirmation_number
        }
      )
    end
  end
end
