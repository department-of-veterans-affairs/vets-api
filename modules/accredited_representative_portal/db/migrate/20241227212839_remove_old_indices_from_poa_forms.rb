class RemoveOldIndicesFromPoaForms < ActiveRecord::Migration[7.1]
  def change
    remove_index :ar_power_of_attorney_forms, name: 'idx_on_city_bidx_state_bidx_zipcode_bidx_a85b76f9bc', column: [:city_bidx, :state_bidx, :zipcode_bidx]
    remove_index :ar_power_of_attorney_forms, name: 'index_ar_power_of_attorney_forms_on_zipcode_bidx', column: :zipcode_bidx
  end
end
