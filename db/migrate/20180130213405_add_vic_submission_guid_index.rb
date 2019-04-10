class AddVICSubmissionGuidIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:vic_submissions, :guid, unique: true, algorithm: :concurrently)
  end
end
