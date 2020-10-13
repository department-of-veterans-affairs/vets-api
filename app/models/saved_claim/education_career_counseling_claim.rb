# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
  FORM = '28-8832'

  def regional_office
    []
  end

  def add_claimant_info(current_user)
    updated_form = parsed_form
    updated_form['claimantInformation'] = {
      'fullName' => {
        'first' => current_user.first_name,
        'middle' => current_user.middle_name || '',
        'last' => current_user.last_name
      },
      'veteranSocialSecurityNumber' => current_user.ssn,
      'dateOfBirth' => current_user.birth_date
    }

    updated_form['veteranFullName'] = {
      'first' => current_user.first_name,
      'middle' => current_user.middle_name || '',
      'last' => current_user.last_name
    }

    update(form: updated_form.to_json)
  end
end
