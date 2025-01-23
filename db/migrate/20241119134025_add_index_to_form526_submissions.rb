class AddIndexToForm526Submissions < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :form526_submissions, :backup_submitted_claim_id, algorithm: :concurrently
  end
end
