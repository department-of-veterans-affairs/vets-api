class CreateSchemaContractValidations < ActiveRecord::Migration[7.0]
  def change
    create_table :schema_contract_validations do |t|
      t.string :contract_name, null: false
      t.string :user_uuid, null: false
      t.jsonb :response, null: false
      t.integer :status, null: false
      t.string :error_details

      t.timestamps
    end
  end
end
