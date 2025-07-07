class CreateAccreditationApiEntityCount < ActiveRecord::Migration[7.2]
  def change
    create_table :accreditation_api_entity_counts do |t|
      t.integer :agents
      t.integer :attorneys
      t.integer :representatives
      t.integer :veteran_service_organizations
      t.timestamps
    end
  end
end
