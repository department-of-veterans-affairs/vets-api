class ValidateOrganizationRepresentativesAcceptanceModeCheck < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :organization_representatives, name: 'org_reps_acceptance_mode_check'
  end
end
