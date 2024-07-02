class AddDeleteDateToSavedClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_claims, :delete_date, :datetime, null: true
  end
end
