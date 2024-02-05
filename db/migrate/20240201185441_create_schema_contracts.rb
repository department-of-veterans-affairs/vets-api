class CreateSchemaContracts < ActiveRecord::Migration[6.1]
  def change
    create_table :schema_contracts do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :user_uuid
      t.jsonb :response

      t.timestamps
    end
  end
end
