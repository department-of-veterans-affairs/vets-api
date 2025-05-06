class AddUserAccountToSchemaContractValidations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :schema_contract_validations, :user_account, type: :uuid, null: true, index: { algorithm: :concurrently }
    add_foreign_key :schema_contract_validations, :user_accounts, validate: false
  end
end
