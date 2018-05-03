class AddMhvCorrelationIdToMhvAccounts < ActiveRecord::Migration
  def change
    # accounts can be disabled, new ones could be created, as a log
    # it is entirely feasible to have more than one mhv account created by vets.gov
    # if a previously created or upgraded one has since been disabled.
    # it's also entirely feasible for MHV to recycle existing mhv_correlation_ids
    # so no uniquness constraints can exist here.

    # first we will drop the index
    remove_index :mhv_accounts, name: 'index_mhv_accounts_on_user_uuid'
    # remove uniquness constraint
    change_column :mhv_accounts, :user_uuid, :string, unique: false
    # add the new column
    add_column :mhv_accounts, :mhv_correlation_id, :string

    # add indexes for both
    add_index :mhv_accounts, [:user_uuid, :mhv_correlation_id]
  end
end
