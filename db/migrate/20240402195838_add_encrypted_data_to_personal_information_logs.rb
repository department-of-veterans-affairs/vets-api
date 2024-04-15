class AddEncryptedDataToPersonalInformationLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :personal_information_logs, :data_ciphertext, :text
    add_column :personal_information_logs, :encrypted_kms_key, :text
  end
end
