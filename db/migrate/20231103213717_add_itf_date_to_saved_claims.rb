class AddItfDateToSavedClaims < ActiveRecord::Migration[6.1]
  def change
    add_column :saved_claims, :itf_datetime, :datetime
  end
end
