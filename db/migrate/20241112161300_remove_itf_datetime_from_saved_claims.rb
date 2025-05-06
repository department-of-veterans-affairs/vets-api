class RemoveItfDatetimeFromSavedClaims < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :saved_claims, :itf_datetime, :datetime, if_exists: true }
  end
end
