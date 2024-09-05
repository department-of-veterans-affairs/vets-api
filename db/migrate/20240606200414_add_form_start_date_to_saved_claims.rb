class AddFormStartDateToSavedClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_claims, :form_start_date, :datetime
  end
end
