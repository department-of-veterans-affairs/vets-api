class CreateOrganizationRepresentatives < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_representatives do |t|
      t.string :representative_id, null: false
      t.string :organization_poa, null: false, limit: 3
      t.string :acceptance_mode, null: false, default: 'disabled'

      t.timestamps
    end
  end
end
