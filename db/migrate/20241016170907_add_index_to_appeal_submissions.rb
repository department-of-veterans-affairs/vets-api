class AddIndexToAppealSubmissions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :appeal_submissions, :submitted_appeal_uuid, algorithm: :concurrently
  end
end
