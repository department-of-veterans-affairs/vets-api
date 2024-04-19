class AddIpfDataToForm5655Submission < ActiveRecord::Migration[7.1]
  def change
    add_column :form5655_submissions, :ipf_data_ciphertext, :text
  end
end
