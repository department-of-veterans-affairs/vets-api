class AddUserAccountUuidToVeteranOnboardings < ActiveRecord::Migration[7.1]
  def change
    add_column :veteran_onboardings, :user_account_uuid, :string
    # because this table is currently unused, there is no concern about
    # locking the table when adding an index
    safety_assured { add_index :veteran_onboardings, :user_account_uuid, unique: true}
  end
end
