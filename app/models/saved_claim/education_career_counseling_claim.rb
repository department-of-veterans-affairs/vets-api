# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
  include SentryLogging
  FORM = '28-8832'

  def regional_office
    []
  end

  def send_to_central_mail!
    form_copy = parsed_form

    if form_copy['veteranSocialSecurityNumber'].blank?
      claimant_info = parsed_form['claimantInformation']
      form_copy['veteranSocialSecurityNumber'] = claimant_info['ssn'] || claimant_info['veteranSocialSecurityNumber']

      update(form: form_copy.to_json)
    end

    log_message_to_sentry(guid, :warn, { attachment_id: guid }, { team: 'vfs-ebenefits' })
    process_attachments!
  end
end
