class AddForeignKeysToOrganizationRepresentatives < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :organization_representatives,
                    :veteran_representatives,
                    column: :representative_id,
                    primary_key: :representative_id,
                    validate: false,
                    if_not_exists: true

    add_foreign_key :organization_representatives,
                    :veteran_organizations,
                    column: :organization_poa,
                    primary_key: :poa,
                    validate: false,
                    if_not_exists: true

    add_check_constraint :organization_representatives,
                         "acceptance_mode IN ('any_request','self_only','disabled')",
                         name: 'org_reps_acceptance_mode_check',
                         validate: false
  end
end
