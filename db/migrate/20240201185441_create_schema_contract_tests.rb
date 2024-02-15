class CreateSchemaContractTests < ActiveRecord::Migration[6.1]
  def change
    create_table :schema_contract_tests do |t|
      t.string :name, null: false # should probably rename this to something more specific
      t.string :user_uuid, null: false
      t.jsonb :response, null: false
      t.string :status
      t.string :error_details

      t.timestamps
    end
  end
end
