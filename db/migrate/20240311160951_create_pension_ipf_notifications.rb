class CreatePensionIpfNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :pension_ipf_notifications do |t|
      t.text :payload_ciphertext
      t.text :encrypted_kms_key

      t.timestamps
    end
  end
end
