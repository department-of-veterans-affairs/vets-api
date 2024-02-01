class CreateSchemaContracts < ActiveRecord::Migration[6.1]
  def change
    create_table :schema_contracts do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :last_user_uuid
      t.jsonb :last_response
      t.string :schema
      t.timestamp :last_run
      t.timestamps
    end
  end
end
