class AddBillValToAccounts < ActiveRecord::Migration[6.0]
  def change
    add_column :accounts, :bill_val, :string
  end
end
