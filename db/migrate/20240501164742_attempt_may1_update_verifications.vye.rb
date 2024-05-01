# This migration comes from vye (originally 20240501000103)
class AttemptMay1UpdateVerifications < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_verifications, :user_profile_id, :integer unless column_exists?(:vye_verifications, :user_profile_id)
    add_column :vye_verifications, :monthly_rate, :decimal unless column_exists?(:vye_verifications, :monthly_rate)
    add_column :vye_verifications, :number_hours, :integer unless column_exists?(:vye_verifications, :number_hours)
    add_column :vye_verifications, :payment_date, :date unless column_exists?(:vye_verifications, :payment_date)
    add_column :vye_verifications, :transact_date, :date unless column_exists?(:vye_verifications, :transact_date)
    add_column :vye_verifications, :trace, :string unless column_exists?(:vye_verifications, :trace)
  end
end
