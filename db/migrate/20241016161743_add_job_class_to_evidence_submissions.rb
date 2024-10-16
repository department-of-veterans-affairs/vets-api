class AddJobClassToEvidenceSubmissions < ActiveRecord::Migration[7.1]
  def change
    add_column :evidence_submissions, :job_class, :string
  end
end
