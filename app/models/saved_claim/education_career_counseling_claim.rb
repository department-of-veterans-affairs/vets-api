# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
  include SentryLogging
  FORM = '28-8832'

  def regional_office
    []
  end

  def add_claimant_info(current_user)
    return if form.blank?

    updated_form = parsed_form

    updated_form['claimantInformation'] = {
      'fullName' => {
        'first' => current_user.first_name,
        'middle' => current_user.middle_name || '',
        'last' => current_user.last_name
      },
      'veteranSocialSecurityNumber' => current_user.ssn,
      'dateOfBirth' => claimant_birth_date(current_user)
    }

    # only populate the veteran information with the current user info
    # if status isVeteran or isActiveDuty
    if updated_form['status'] == 'isVeteran' || updated_form['status'] == 'isActiveDuty'
      updated_form['veteranFullName'] = {
        'first' => current_user.first_name,
        'middle' => current_user.middle_name || '',
        'last' => current_user.last_name
      }
    end

    update(form: updated_form.to_json)
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

  private

  def claimant_birth_date(current_user)
    if current_user.birth_date.respond_to?(:strftime)
      current_user.birth_date.strftime('%Y-%m-%d')
    else
      current_user.birth_date
    end
  end
end
