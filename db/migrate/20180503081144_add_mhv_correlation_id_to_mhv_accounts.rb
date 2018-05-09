class AddMhvCorrelationIdToMhvAccounts < ActiveRecord::Migration
  def change
    # accounts can be disabled, new ones could be created
    # it is entirely feasible to have more than one mhv account created by vets.gov
    # if a previously created or upgraded one has since been disabled.
    # it's also entirely feasible for MHV to recycle existing mhv_correlation_ids
    # so no uniqueness constraints can exist here.

    # first we will drop the index
    remove_index :mhv_accounts, column: :user_uuid
    # remove uniqueness constraint
    change_column :mhv_accounts, :user_uuid, :string, unique: false
    # add the new column; we would love to put null: false here but obviously thats not possible
    add_column :mhv_accounts, :mhv_correlation_id, :string, unique: false, null: true

    # add indexes for both (will do this in seperate migration)
    # add_index :mhv_accounts, [:user_uuid, :mhv_correlation_id], unique: true
  end
end
