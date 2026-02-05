class CreateOrganizationRepresentatives < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_representatives do |t|
      t.string :representative_id, null: false
      t.string :organization_poa, null: false, limit: 3
      t.string :acceptance_mode, null: false, default: 'disabled'

      t.timestamps
    end

    add_foreign_key :organization_representatives, :veteran_representatives,
                    column: :representative_id, primary_key: :representative_id, validate: false
    add_foreign_key :organization_representatives, :veteran_organizations,
                    column: :organization_poa, primary_key: :poa, validate: false
  end
end
