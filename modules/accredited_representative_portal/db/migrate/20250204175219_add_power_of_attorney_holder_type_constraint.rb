class AddPowerOfAttorneyHolderTypeConstraint < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :ar_user_account_accredited_individuals,
      [:power_of_attorney_holder_type, :user_account_email],
      unique: true,
      name: 'ar_uniq_power_of_attorney_holder_type_user_account_email',
      algorithm: :concurrently
  end
end
