class CreateSchemaContracts < ActiveRecord::Migration[6.1]
  def change
    create_table :schema_contracts do |t|
      t.string :name, null: false
      t.string :user_uuid
      t.jsonb :response
      t.string :status

      t.timestamps
    end
  end
end
