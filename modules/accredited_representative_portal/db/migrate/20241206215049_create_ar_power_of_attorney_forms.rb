class CreateArPowerOfAttorneyForms < ActiveRecord::Migration[7.0]
  def change
    create_table :ar_power_of_attorney_forms, id: :uuid do |t|
      t.references :ar_power_of_attorney_request,
        type: :uuid,
        foreign_key: true,
        index: { name: 'index_ar_poa_forms_on_ar_poa_request_id' }  # shortened name
      t.text :data_ciphertext
      t.string :city_bidx
      t.string :state_bidx
      t.string :zipcode_bidx
    end
  end
end
