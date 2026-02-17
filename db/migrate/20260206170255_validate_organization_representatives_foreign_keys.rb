class ValidateOrganizationRepresentativesForeignKeys < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :organization_representatives, :veteran_representatives, column: :representative_id
    validate_foreign_key :organization_representatives, :veteran_organizations, column: :organization_poa
  end
end
