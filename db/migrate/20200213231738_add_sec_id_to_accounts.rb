class AddSecIdToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :sec_id, :string
  end
end
