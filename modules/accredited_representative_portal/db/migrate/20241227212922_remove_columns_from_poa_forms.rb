class RemoveColumnsFromPoaForms < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_columns :ar_power_of_attorney_forms, :city_bidx, :state_bidx, :zipcode_bidx, type: :string }
  end
end
