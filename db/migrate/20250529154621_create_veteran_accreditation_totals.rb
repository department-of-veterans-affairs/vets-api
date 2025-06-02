class CreateVeteranAccreditationTotals < ActiveRecord::Migration[7.2]
  def change
    create_table :veteran_accreditation_totals do |t|
      t.integer :attorneys
      t.integer :claims_agents
      t.integer :vso_representatives
      t.integer :vso_organizations
      t.timestamps
    end
  end
end
