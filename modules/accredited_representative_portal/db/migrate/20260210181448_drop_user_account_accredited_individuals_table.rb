class DropUserAccountAccreditedIndividualsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :ar_user_account_accredited_individuals do |t|
      t.string :accredited_individual_registration_number, null: false
      t.string :power_of_attorney_holder_type, null: false
      t.string :user_account_email, null: false
      t.string :user_account_icn
    end
  end
end
