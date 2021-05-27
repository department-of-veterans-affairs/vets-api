# frozen_string_literal: true

class SavedClaim::DependencyVerificationClaim < CentralMailClaim
  include SentryLogging
  FORM = '21-0538'

  def regional_office
    []
  end

  def send_to_central_mail!
    form_copy = parsed_form

    if form_copy['veteranSocialSecurityNumber'].blank?
      form_copy['veteranSocialSecurityNumber'] = parsed_form['veteranInformation']['ssn']

      update(form: form_copy.to_json)
    end

    log_message_to_sentry(guid, :warn, { attachment_id: guid }, { team: 'vfs-ebenefits' })
    process_attachments!
  end

  def add_claimant_info(user)
    updated_form = parsed_form

    updated_form.merge!(
      {
        'updateDiaries' => true,
        'veteranInformation' => {
          'fullName' => {
            'first' => user.first_name,
            'middleInitial' => user.middle_name,
            'last' => user.last_name
          },
          'ssn' => user.ssn,
          'dateOfBirth' => user.birth_date,
          'email' => user.email
        }
      }
    ).except!('update_diaries')

    update(form: updated_form.to_json)
  end
end
