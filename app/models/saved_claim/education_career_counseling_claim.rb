# frozen_string_literal: true

class SavedClaim::EducationCareerCounselingClaim < CentralMailClaim
  FORM = '28-8832'

  def regional_office
    []
  end

  def add_veteran_info(current_user)
    parsed_form.merge!(
      {
        'claimant_information' => {
          'full_name' => {
            'first' => current_user.first_name,
            'middle' => current_user.middle_name,
            'last' => current_user.last_name
          },
          'ssn' => current_user.ssn,
          'date_of_birth' => current_user.birth_date
        }
      }
    )
  end
end
