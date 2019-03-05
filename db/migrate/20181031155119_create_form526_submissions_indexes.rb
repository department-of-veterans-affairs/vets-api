class CreateForm526SubmissionsIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:form526_submissions, :user_uuid, algorithm: :concurrently)
    add_index(:form526_submissions, :saved_claim_id, unique: true, algorithm: :concurrently)
    add_index(:form526_submissions, :submitted_claim_id, unique: true, algorithm: :concurrently)
  end
end
