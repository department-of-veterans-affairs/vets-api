class AddIndexToArUserAccountAccreditedIndividuals < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :ar_user_account_accredited_individuals,
      %i[accredited_individual_registration_number power_of_attorney_holder_type user_account_email],
      unique: true,
      name: 'index_ar_user_account_accredited_individuals_unique',
      algorithm: :concurrently
  end
end
