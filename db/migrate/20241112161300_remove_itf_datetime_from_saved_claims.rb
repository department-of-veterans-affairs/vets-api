class RemoveItfDatetimeFromSavedClaims < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :saved_claims, :itf_datetime, :datetime }
  end
end
