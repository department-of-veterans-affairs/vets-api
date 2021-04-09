class AddFieldsToEvidenceSubmissions < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_evidence_submissions, :source, :string
    add_column :appeals_api_evidence_submissions, :code, :string
    add_column :appeals_api_evidence_submissions, :details, :string
  end
end
