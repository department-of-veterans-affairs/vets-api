class CreateArPowerOfAttorneyFormSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_power_of_attorney_form_submissions do |t|
      t.uuid :power_of_attorney_request_id, null: false
      t.string :service_id
      t.text :service_response_ciphertext
      t.string :status, null: false
      t.text :encrypted_kms_key
      t.datetime :status_updated_at
      t.text :error_message_ciphertext
      t.datetime :created_at, null: false
    end
  end
end
