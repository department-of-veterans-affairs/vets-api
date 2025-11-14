# frozen_string_literal: true

class SavedClaim::DependencyVerificationClaim < CentralMailClaim
  FORM = '21-0538'

  def regional_office
    []
  end

  def send_to_central_mail!
    form_copy = parsed_form

    form_copy['veteranSocialSecurityNumber'] = parsed_form.dig('dependencyVerification', 'veteranInformation', 'ssn')
    form_copy['veteranFullName'] = parsed_form.dig('dependencyVerification', 'veteranInformation', 'fullName')
    form_copy['veteranAddress'] = ''

    update(form: form_copy.to_json)

    Rails.logger.warn('Attachment processed', { attachment_id: guid, team: 'vfs-ebenefits' })
    process_attachments!
  end

  def add_claimant_info(user)
    updated_form = parsed_form

    updated_form.merge!(
      {
        'dependencyVerification' => {
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
      }
    ).except!('update_diaries')

    update(form: updated_form.to_json)
  end
end
