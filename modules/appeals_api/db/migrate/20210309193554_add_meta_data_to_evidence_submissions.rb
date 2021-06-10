class AddMetaDataToEvidenceSubmissions < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_evidence_submissions, :encrypted_file_data, :string
    add_column :appeals_api_evidence_submissions, :encrypted_file_data_iv, :string
  end
end
