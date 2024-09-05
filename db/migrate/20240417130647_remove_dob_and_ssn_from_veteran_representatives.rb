class RemoveDobAndSsnFromVeteranRepresentatives < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :veteran_representatives, :ssn_ciphertext, :text
      remove_column :veteran_representatives, :dob_ciphertext, :text
      remove_column :veteran_representatives, :encrypted_kms_key, :text
    end
  end
end
