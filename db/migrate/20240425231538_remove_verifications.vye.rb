class RemoveVerifications < ActiveRecord::Migration[7.1]
  def change
    remove_index "vye_verifications", column: [:user_profile_id], name: "index_vye_verifications_on_user_profile_id", if_exists: true

    safety_assured { remove_column :vye_verifications, :user_profile_id, :integer, if_exists: true }
    safety_assured { remove_column :vye_verifications, :monthly_rate, :decimal, if_exists: true }
    safety_assured { remove_column :vye_verifications, :number_hours, :integer, if_exists: true }
    safety_assured { remove_column :vye_verifications, :payment_date, :date, if_exists: true }
    safety_assured { remove_column :vye_verifications, :transact_date, :date, if_exists: true }
    safety_assured { remove_column :vye_verifications, :trace, :string, if_exists: true }
  end
end
