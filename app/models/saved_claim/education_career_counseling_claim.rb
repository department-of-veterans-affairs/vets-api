# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
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

    updated_form['veteranFullName'] = {
      'first' => current_user.first_name,
      'middle' => current_user.middle_name || '',
      'last' => current_user.last_name
    }

    update(form: updated_form.to_json)
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
