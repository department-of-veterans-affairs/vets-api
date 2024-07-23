class RenameFormDataToFormDataCiphertext < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :form_submissions, :form_data, :jsonb }
    add_column :form_submissions, :form_data_ciphertext, :jsonb
  end
end
