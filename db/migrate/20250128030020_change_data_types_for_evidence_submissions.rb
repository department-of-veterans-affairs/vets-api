class ChangeDataTypesForEvidenceSubmissions < ActiveRecord::Migration[7.2]
  # Change request_id from a string to an integer
  # Change claim_id from a string to an integer
  # Change tracked_item_id from a string to an integer

  def change
    safety_assured do
      change_column :evidence_submissions, :request_id, :integer, using: 'request_id::integer'
      change_column :evidence_submissions, :claim_id, :integer, using: 'claim_id::integer'
      change_column :evidence_submissions, :tracked_item_id, :integer, using: 'tracked_item_id::integer'
    end
  end
end
