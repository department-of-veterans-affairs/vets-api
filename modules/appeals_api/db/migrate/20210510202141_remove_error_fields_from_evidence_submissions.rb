class RemoveErrorFieldsFromEvidenceSubmissions < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      remove_column :appeals_api_evidence_submissions, :code, :string
      remove_column :appeals_api_evidence_submissions, :detail, :string
    end
  end
end
