class AddFileSizeToEvidenceSubmission < ActiveRecord::Migration[7.2]
  def up
    add_column :evidence_submissions, :file_size, :integer
  end
end
