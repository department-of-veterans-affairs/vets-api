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

  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    CentralMail::SubmitSavedClaimJob.new.perform(id)
  end

  def business_line
    'EDU'
  end
end
