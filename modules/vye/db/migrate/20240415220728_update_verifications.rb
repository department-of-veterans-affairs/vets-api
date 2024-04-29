class UpdateVerifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :vye_verifications, :user_profile_id, :integer
    add_column :vye_verifications, :monthly_rate, :decimal
    add_column :vye_verifications, :number_hours, :integer
    add_column :vye_verifications, :payment_date, :date
    add_column :vye_verifications, :transact_date, :date
    add_column :vye_verifications, :trace, :string
  end
end
