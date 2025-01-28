class CreateArPowerOfAttorneyFormSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_power_of_attorney_form_submissions do |t|
      t.uuid :power_of_attorney_request_id, null: false
      t.string :service_id
      t.jsonb :service_response_ciphertext
      t.string :status, default: 'pending'
      t.datetime :status_updated_at
      t.text :error_message_ciphertext

      t.timestamps
    end
  end
end
